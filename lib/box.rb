class Box
  attr_reader :hostname, :password, :user

  def initialize(hostname, user=nil, password=nil)
    @hostname = hostname
    @user     = user ? user : $conf.user
    @password = password ? password : $conf.pass

    @ssh_connection = Net::SSH.start(@hostname, @user, password: @password)
    @logger = Logger.new("#{$app_directory}/log/#{hostname}")
  end

  def self.all
    BoxGroup.new($conf.hostnames.map{ |hostname| Box.new(hostname) })
  end

  def self.all_with_role(role)
    raise "Not implemented yet."
  end

  def self.find(identifier)
    if identifier == 'cm'
      Box.new($conf.cm.host)
    else
      nil
    end
  end

  def cmd(command, verbose=$conf.debug_mode)
    start_time = Time.now
    log "BEGIN: #{command}"

    if verbose
      result = @ssh_connection.exec!(command)
      log result
    else
      result = @ssh_connection.exec!(command)
    end

    end_time = Time.now
    duration = end_time - start_time
    log "END (#{duration}s) \n\n"

    result
  end

  def scp(file_to_copy_path, destination_path)
    log "Copying #{file_to_copy_path} to #{destination_path}"
    Net::SCP.upload!(@hostname,
                    $conf.user,
                    file_to_copy_path,
                    destination_path,
                    :ssh => { :password => $conf.password },
                    recursive: true)
  end

  def mysql(query)
    cmd "mysql -e \"#{query}\""
  end

  def install(package_name, service_name=nil)
    # TODO - Check for errors, store in var, report at end of run
    log "Checking if #{package_name} is installed"

    if (cmd "rpm -q #{package_name}") =~ /is not installed/
      log "Installing #{package_name}"

      cmd "yum install -y #{package_name}"

      log "#{package_name} installation complete"

      if service_name
        service(service_name).start_and_enable

        status = service(service_name).status
        raise "ERROR: #{service_name} could not be started on #{@hostname}" unless status =~ /active \(running\)/
      end

      return true
    else
      log "#{package_name} is already installed"
      return false
    end
  end

  def service(name)
    Service.new(name, self)
  end

  def set_swappiness(amount=1)
    log "Setting 'swappiness' to #{amount}."
    cmd "sh -c 'echo #{amount} > /proc/sys/vm/swappiness'"
  end

  def disable_transparent_hugepage
    thp_defrag_res = cmd "cat /sys/kernel/mm/transparent_hugepage/defrag"
    thp_res        = cmd "cat /sys/kernel/mm/transparent_hugepage/enabled"

    if thp_res =~ /\[never\]/ && thp_defrag_res =~ /\[never\]/
      log "transparent_hugepage already disabled"
    else
      log "Disabling transparent_hugepage"
      cmd "echo never > /sys/kernel/mm/transparent_hugepage/enabled"
      cmd "echo never > /sys/kernel/mm/transparent_hugepage/defrag"

      log "Modifying /etc/rc.d/rc.local to disable transparent_hugepage on startup"
      rc_local_file = cmd "cat /etc/rc.d/rc.local"

      unless rc_local_file =~ /\/sys\/kernel\/mm\/transparent_hugepage\/defrag/
        log "Adding 'echo never > /sys/kernel/mm/transparent_hugepage/defrag'"
        cmd "echo 'echo never > /sys/kernel/mm/transparent_hugepage/defrag' >> /etc/rc.d/rc.local"
      end

      unless rc_local_file =~ /\/sys\/kernel\/mm\/transparent_hugepage\/enabled/
        log "Adding 'echo never > /sys/kernel/mm/transparent_hugepage/enabled'"
        cmd "echo 'echo never > /sys/kernel/mm/transparent_hugepage/enabled' >> /etc/rc.d/rc.local"
      end

      log "Ensuring /etc/rc.d/rc.local is executable"
      cmd "chmod +x /etc/rc.d/rc.local"
    end
  end

  def deploy_mysql_my_cnf(master_or_slave)
    if cmd("cat /etc/my.cnf") =~ /CTK/
      log "/etc/my.cnf already deployed"
    else
      log "Deploying /etc/my.cnf"
      scp("./files/mysql_#{master_or_slave}_config.my.cnf", "/etc/my.cnf")
      log "Removing /var/lib/mysql/ib_logfile*"
      cmd "rm -f /var/lib/mysql/ib_logfile*"
      service('mariadb').restart
    end
  end

  def install_jdk
    if cmd("yum list installed | grep jdk") =~ /jdk1\.8/
      log "JDK for Java 8 already installed"
      return
    end

    log "Installing JDK for Java 8"

    # XXX - Oracle likes to change the link to their JDK downloads.  If needed, get the new one from this page:
    # http://www.oracle.com/technetwork/java/javase/downloads/jdk8-downloads-2133151.html
    cmd 'cd /tmp; curl -L -b "oraclelicense=a" http://download.oracle.com/otn-pub/java/jdk/8u171-b11/512cd62ec5174c3487ac17c61aaa89e8/jdk-8u171-linux-x64.rpm -O'

    log "Deploying /etc/profile.d/java.sh"
    scp("./files/java.sh", "/etc/profile.d/java.sh")

    cmd "chmod 744 /etc/profile.d/java.sh"
    cmd "source /etc/profile.d/java.sh"

    log "Installing JDK 8 RPM"
    cmd "yum localinstall -y /tmp/jdk-8u171-linux-x64.rpm"
  end

  def install_jdbc_driver
    if cmd("ls /usr/share/java") =~ /mysql-connector-java\.jar/
      log "JDBC driver already installed"
      return
    end

    log "Installing JDBC driver - mysql-connector-java-5.1.45-bin.jar - in /usr/share/java"
    
    log "Downloading JDBC driver"
    cmd "wget https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.45.tar.gz"
    cmd "tar -xzf mysql-connector-java-5.1.45.tar.gz"

    log "Moving and renaming JDBC driver"
    cmd "mkdir /usr/share/java"
    cmd "mv mysql-connector-java-5.1.45/mysql-connector-java-5.1.45-bin.jar /usr/share/java/mysql-connector-java.jar"
    cmd "rm -rf mysql-connector-java-5.1.45*"
  end

  def install_cloudera_manager
    install "yum-utils"

    cmd "yum-config-manager --add-repo https://archive.cloudera.com/cm5/redhat/7/x86_64/cm/cloudera-manager.repo"

    install "cloudera-manager-daemons"
    install "cloudera-manager-server"

    log "Verifying Cloudera Manager databases are configured properly"
    cmd "/usr/share/cmf/schema/scm_prepare_database.sh mysql cmserver cmserver_user #{$conf.mysql_cm_dbs_password}"

    service('cloudera-scm-server').start_and_enable
  end

  def test_connection
    raise "Must connect as root." if $conf.user != 'root'
    raise "Could not connect to #{@hostname}" unless cmd "hostname"=~ /#{@hostname}/
    true
  end

  def log(msg)
    if $running_in_parallel
      @logger.info(msg)
    else
      puts msg
      @logger.info(msg)
    end
  end
end

# TODO:
# - Should be able to swith user
# - Run command should have option to run as a different user
# - ...

class Server
  attr_reader :hostname, :password, :user

  def initialize(hostname, user=nil, password=nil)
    @conf     = Config.load
    @hostname = hostname
    @user     = user ? user : @conf.user
    @password = password ? password : @conf.pass

    @ssh_connection = Net::SSH.start(@hostname, @user, password: @password)
  end

  def test_connection
    raise "Must connect as root." if @conf.user != 'root'
    raise "Could not connect to #{@hostname}" unless run "hostname"=~ /#{@hostname}/
    true
  end

  def set_swappiness(amount=1)
    puts "Setting 'swappiness' to #{amount}."
    run "sh -c 'echo #{amount} > /proc/sys/vm/swappiness'"
  end

  def disable_transparent_hugepage
    thp_defrag_res = run "cat /sys/kernel/mm/transparent_hugepage/defrag"
    thp_res        = run "cat /sys/kernel/mm/transparent_hugepage/enabled"

    if thp_res =~ /\[never\]/ && thp_defrag_res =~ /\[never\]/
      puts "transparent_hugepage already disabled"
    else
      puts "Disabling transparent_hugepage"
      run "echo never > /sys/kernel/mm/transparent_hugepage/enabled"
      run "echo never > /sys/kernel/mm/transparent_hugepage/defrag"

      puts "Modifying /etc/rc.d/rc.local to disable transparent_hugepage on startup"
      rc_local_file = run "cat /etc/rc.d/rc.local"

      unless rc_local_file =~ /\/sys\/kernel\/mm\/transparent_hugepage\/defrag/
        puts "Adding 'echo never > /sys/kernel/mm/transparent_hugepage/defrag'"
        run "echo 'echo never > /sys/kernel/mm/transparent_hugepage/defrag' >> /etc/rc.d/rc.local"
      end

      unless rc_local_file =~ /\/sys\/kernel\/mm\/transparent_hugepage\/enabled/
        puts "Adding 'echo never > /sys/kernel/mm/transparent_hugepage/enabled'"
        run "echo 'echo never > /sys/kernel/mm/transparent_hugepage/enabled' >> /etc/rc.d/rc.local"
      end

      puts "Ensuring /etc/rc.d/rc.local is executable"
      run "chmod +x /etc/rc.d/rc.local"
    end
  end

  def deploy_mysql_my_cnf(master_or_slave)
    if run("cat /etc/my.cnf") =~ /MiddleManager/
      puts "/etc/my.cnf already deployed"
    else
      puts "Deploying /etc/my.cnf"
      scp("./files/mysql_#{master_or_slave}_config.my.cnf", "/etc/my.cnf")
      puts "Removing /var/lib/mysql/ib_logfile*"
      run "rm -f /var/lib/mysql/ib_logfile*"
      restart_mysql
    end
  end

  def install_maria_db
    if install "mariadb-server", "mariadb"
      restart_mysql
    end
  end

  def restart_mysql
    puts "Restarting mariadb service"
    res = run "systemctl restart mariadb"
    if res.strip.length > 0
      puts "Error: \n"
      puts res.inspect
      raise "MariaDB restart failed on #{@hostname}"
    end
  end

  def mysql_secure_installation
    puts "Securing MySQL installation"

    # Set root password
    mysql "UPDATE mysql.user SET Password = PASSWORD('#{@conf.mysql_root_pass}') WHERE User = 'root'"

    # Remove anonymous users
    mysql "DROP USER ''@'localhost'"

    # Because our hostname varies we'll use some Bash magic here.
    mysql "DROP USER ''@'$(hostname)'"

    # Remove the test database
    mysql "DROP DATABASE test"

    # Make our changes take effect
    mysql "FLUSH PRIVILEGES"

    # Automate mysql logins for the root user via ~/.my.cnf file
    run "echo [client] > ~/.my.cnf"
    run "echo user=root >> ~/.my.cnf"
    run "echo pass=#{@conf.mysql_root_pass} >> ~/.my.cnf"

    # Lock it down, only root should see this file
    run "chmod 600 ~/.my.cnf"
  end

  def mysql_replication_setup(master_host, slave_host)
    @ssh_connection = Net::SSH.start(slave_host, @conf.user, password: @conf.password)
    if mysql("SHOW SLAVE STATUS\\G") =~ /Waiting for master to send event/
      puts "MySQL replication is already working"
      return
    end

    puts "Configuring MySQL replication between #{master_host} and #{slave_host}"

    puts "Creating slave user"
    @ssh_connection = Net::SSH.start(master_host, @conf.user, password: @conf.password)
    mysql "GRANT REPLICATION SLAVE ON *.* TO 'slave_user'@'%' IDENTIFIED BY '#{@conf.mysql_slave_user_pass}';"
    mysql "SET GLOBAL binlog_format = 'ROW';"
    mysql "FLUSH TABLES WITH READ LOCK;"
    master_status = run "mysql -e \"SHOW MASTER STATUS;\""

    # master_status looks like:
    # "File\tPosition\tBinlog_Do_DB\tBinlog_Ignore_DB\nmysql_binary_log.000014\t2172\t\t\n"
    master_log_file = master_status.split("\n").last.split(" ").first
    master_log_pos  = master_status.split("\n").last.split(" ").last

    run "mysql -e \"UNLOCK TABLES;\""

    puts "Configuring slave"
    @ssh = Net::SSH.start(slave_host, @conf.user, password: @conf.password)
    mysql "CHANGE MASTER TO MASTER_HOST='#{master_host}', MASTER_USER='slave_user', MASTER_PASSWORD='#{@conf.mysql_slave_user_pass}', MASTER_LOG_FILE='#{master_log_file}', MASTER_LOG_POS=#{master_log_pos};"
    mysql "START SLAVE;"
    mysql "SHOW SLAVE STATUS\\G"

    puts "MySQL replication setup complete"
  end

  def install_jdk
    if run("yum list installed | grep jdk") =~ /jdk1\.8/
      puts "JDK for Java 8 already installed"
      return
    end

    puts "Installing JDK for Java 8"

    # XXX - Oracle likes to change the link to their JDK downloads.  If needed, get the new one from this page:
    # http://www.oracle.com/technetwork/java/javase/downloads/jdk8-downloads-2133151.html
    run 'cd /tmp; curl -L -b "oraclelicense=a" http://download.oracle.com/otn-pub/java/jdk/8u161-b12/2f38c3b165be4555a1fa6e98c45e0808/jdk-8u161-linux-x64.rpm -O'

    puts "Deploying /etc/profile.d/java.sh"
    scp("./files/java.sh", "/etc/profile.d/java.sh")

    run "chmod 744 /etc/profile.d/java.sh"
    run "source /etc/profile.d/java.sh"

    puts "Installing JDK 8 RPM"
    run "yum localinstall -y /tmp/jdk-8u161-linux-x64.rpm"
  end

  def install_nmon
    install "nmon"
  end

  def install_jdbc_driver
    if run("ls /usr/share/java") =~ /mysql-connector-java\.jar/
      puts "JDBC driver already installed"
      return
    end

    puts "Installing JDBC driver - mysql-connector-java-5.1.45-bin.jar - in /usr/share/java"
    
    puts "Downloading JDBC driver"
    run "wget https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.45.tar.gz"
    run "tar -xzf mysql-connector-java-5.1.45.tar.gz"

    puts "Moving and renaming JDBC driver"
    run "mkdir /usr/share/java"
    run "mv mysql-connector-java-5.1.45/mysql-connector-java-5.1.45-bin.jar /usr/share/java/mysql-connector-java.jar"
    run "rm -rf mysql-connector-java-5.1.45*"
  end

  def setup_cm_dbs
    puts "Creating databases/users for Cloudera Manager"
    ['cmserver', 'hive', 'amon', 'rman', 'oozie', 'hue'].each do |db_name|
      puts "Creating #{db_name} database and #{db_name}_user user."

      mysql "CREATE DATABASE #{db_name} DEFAULT CHARACTER SET utf8;"
      mysql "DROP USER IF EXISTS '#{db_name}_user'@'%';"
      mysql "GRANT ALL on #{db_name}.* TO '#{db_name}_user'@'%' IDENTIFIED BY '#{@conf.mysql_cm_dbs_password}';"
    end
  end

  def install_cloudera_manager
    install "yum-utils"

    run "yum-config-manager --add-repo https://archive.cloudera.com/cm5/redhat/7/x86_64/cm/cloudera-manager.repo"

    install "cloudera-manager-daemons"
    install "cloudera-manager-server"

    puts "Verifying Cloudera Manager databases are configured properly"
    run "/usr/share/cmf/schema/scm_prepare_database.sh mysql cmserver cmserver_user #{@conf.mysql_cm_dbs_password}"

    puts "Starting cloudera-scm-server"
    run "systemctl start cloudera-scm-server"
  end

  def run(cmd, verbose=@conf.debug_mode)
    start_time = Time.now
    puts "BEGIN: #{cmd}"

    if verbose
      result = @ssh_connection.exec!(cmd)
      puts result
    else
      result = @ssh_connection.exec!(cmd)
    end

    end_time = Time.now
    duration = end_time - start_time
    puts "END (#{duration}s) \n\n"

    result
  end

  def scp(file_to_copy_path, destination_path)
    Net::SCP.upload!(@hostname,
                    @conf.user,
                    file_to_copy_path,
                    destination_path,
                    :ssh => { :password => @conf.password })
  end

  def mysql(cmd)
    run "mysql -e \"#{cmd}\""
  end

  def install(package_name, service_name=nil)
    # TODO - Check for errors, store in var, report at end of run
    
    if run "rpm -q #{package_name}" =~ /is not installed/ 
      puts "Installing #{package_name}"

      run "yum install -y #{package_name}"

      puts "#{package_name} installation complete"

      if service_name
        run "systemctl start #{service_name}"
        run "systemctl enable #{service_name}"

        status = run "systemctl status #{service_name}"
        raise "ERROR: #{service_name} could not be started on #{@hostname}" unless status =~ /active \(running\)/
      end

      return true
    else
      puts "#{package_name} is already installed"
      return false
    end
  end

  def service(name)
    Service.new(name, self)
  end
end

#binding.pry

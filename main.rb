require 'ostruct'
require 'net/ssh'
require 'net/scp'

class MiddleManager

  attr_reader :conf

  def initialize
    @conf = OpenStruct.new({
      user:                     'root',
      pass:                     'cloudera',
      hosts:                    (1..5).map{ |n| "jmichaels-#{n}.gce.cloudera.com"},
      mysql_root_pass:          'VaT990mLJj',
      mysql_slave_user_pass:    'r47XkHCgpn',
      mysql_cm_dbs_password:    'h1TqkGM3TH',
      cloudera_manager_host:    'jmichaels-1.gce.cloudera.com',
      mysql_replication_host:   nil,
      jdk_rpm_path:             './jdks/jdk-8u161-linux-x64.rpm',
      debug_mode:               true
    })

    @ssh_connection = nil
  end

  def test_connection
    raise "Must connect as root." if @conf.user != 'root'

    puts "Testing connection to hosts"

    @conf.hosts.each do |host|
      puts "Testing connection: ssh #{@conf.user}@#{host}"
      @ssh_connection = Net::SSH.start(host, @conf.user, password: @conf.password)
      result = x "hostname"
      raise "Could not connect to #{host}" unless result =~ /#{host}/
    end
  end

  def run
    test_connection

    @conf.hosts.each do |host|
      puts "Configuring:  #{host}"
      @ssh_connection = Net::SSH.start(host, @conf.user, password: @conf.password)
      @host = host

      set_swappiness
      disable_transparent_hugepage
      ensure_nscd_running
      ensure_ntpd_running
      install_jdbc_driver
      install_jdk
      install_nmon

      if @host == @conf.cloudera_manager_host
        install_maria_db
        deploy_mysql_my_cnf('master')
        install_jdk
        mysql_secure_installation
        setup_cm_dbs
        install_cloudera_manager
      elsif host == @conf.mysql_replication_host
        install_maria_db
        deploy_mysql_my_cnf('slave')
        mysql_secure_installation
      end 
    end

    if @conf.mysql_replication_host
      mysql_replication_setup(@conf.cloudera_manager_host, @conf.mysql_replication_host)
    end

    puts "Server is starting at: http://#{@conf.hosts.first}:7180"
  end

  def set_swappiness
    puts "Setting 'swappiness' to lowest possible value (1)."
    x "sh -c 'echo 1 > /proc/sys/vm/swappiness'"
  end

  def disable_transparent_hugepage
    thp_defrag_res = x "cat /sys/kernel/mm/transparent_hugepage/defrag"
    thp_res        = x "cat /sys/kernel/mm/transparent_hugepage/enabled"

    if thp_res =~ /\[never\]/ && thp_defrag_res =~ /\[never\]/
      puts "transparent_hugepage already disabled"
    else
      puts "Disabling transparent_hugepage"
      x "echo never > /sys/kernel/mm/transparent_hugepage/enabled"
      x "echo never > /sys/kernel/mm/transparent_hugepage/defrag"

      puts "Modifying /etc/rc.d/rc.local to disable transparent_hugepage on startup"
      rc_local_file = x "cat /etc/rc.d/rc.local"

      unless rc_local_file =~ /\/sys\/kernel\/mm\/transparent_hugepage\/defrag/
        puts "Adding 'echo never > /sys/kernel/mm/transparent_hugepage/defrag'"
        x "echo 'echo never > /sys/kernel/mm/transparent_hugepage/defrag' >> /etc/rc.d/rc.local"
      end

      unless rc_local_file =~ /\/sys\/kernel\/mm\/transparent_hugepage\/enabled/
        puts "Adding 'echo never > /sys/kernel/mm/transparent_hugepage/enabled'"
        x "echo 'echo never > /sys/kernel/mm/transparent_hugepage/enabled' >> /etc/rc.d/rc.local"
      end

      puts "Ensuring /etc/rc.d/rc.local is executable"
      x "chmod +x /etc/rc.d/rc.local"
    end
  end

  def ensure_nscd_running
    res = x "service nscd status"
    raise "ERROR: nscd not running on #{@host}" unless res =~ /active \(running\)/
  end

  def ensure_ntpd_running
    res = x "service ntpd status"
    raise "ERROR: ntpd not running on #{@host}" unless res =~ /active \(running\)/
  end

  def deploy_mysql_my_cnf(master_or_slave)
    if x("cat /etc/my.cnf") =~ /MiddleManager/
      puts "/etc/my.cnf already deployed"
    else
      puts "Deploying /etc/my.cnf"
      scp("./files/mysql_#{master_or_slave}_config.my.cnf", "/etc/my.cnf")
      puts "Removing /var/lib/mysql/ib_logfile*"
      x "rm -f /var/lib/mysql/ib_logfile*"
      restart_mysql
    end
  end

  def install_maria_db
    res = x "yum list installed | grep mariadb"
    if res =~ /mariadb-server/
      puts "MariaDB is already installed"
    else
      puts "Installing MariaDB (MySQL)"

      puts "yum install -y mariadb-server"
      x "yum install -y mariadb-server"

      puts "starting mariadb"
      x "systemctl start mariadb"
      x "systemctl enable mariadb"

      restart_mysql

      puts "MariaDB install complete"
    end
  end

  def restart_mysql
    puts "Restarting mariadb service"
    res = x "systemctl restart mariadb"
    if res.strip.length > 0
      puts "Error: \n"
      puts res.inspect
      raise "MariaDB restart failed on #{@host}"
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
    x "echo [client] > ~/.my.cnf"
    x "echo user=root >> ~/.my.cnf"
    x "echo pass=#{@conf.mysql_root_pass} >> ~/.my.cnf"

    # Lock it down, only root should see this file
    x "chmod 600 ~/.my.cnf"
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
    master_status = x "mysql -e \"SHOW MASTER STATUS;\""

    # master_status looks like:
    # "File\tPosition\tBinlog_Do_DB\tBinlog_Ignore_DB\nmysql_binary_log.000014\t2172\t\t\n"
    master_log_file = master_status.split("\n").last.split(" ").first
    master_log_pos  = master_status.split("\n").last.split(" ").last

    x "mysql -e \"UNLOCK TABLES;\""

    puts "Configuring slave"
    @ssh = Net::SSH.start(slave_host, @conf.user, password: @conf.password)
    mysql "CHANGE MASTER TO MASTER_HOST='#{master_host}', MASTER_USER='slave_user', MASTER_PASSWORD='#{@conf.mysql_slave_user_pass}', MASTER_LOG_FILE='#{master_log_file}', MASTER_LOG_POS=#{master_log_pos};"
    mysql "START SLAVE;"
    mysql "SHOW SLAVE STATUS\\G"

    puts "MySQL replication setup complete"
  end

  def install_jdk
    if x("yum list installed | grep jdk") =~ /jdk1\.8/
      puts "JDK for Java 8 already installed"
      return
    end

    puts "Installing JDK for Java 8"

    puts "SCPing JDK 8 RPM to server"
    puts Net::SCP.upload!(@host,
                @conf.user,
                "./jdks/jdk-8u161-linux-x64.rpm",
                "/tmp/",
                :ssh => { :password => @conf.password })

    puts "Deploying /etc/profile.d/java.sh"
    scp("./files/java.sh", "/etc/profile.d/java.sh")

    x "chmod 744 /etc/profile.d/java.sh"
    x "source /etc/profile.d/java.sh"

    puts "Installing JDK 8 RPM"
    x "yum localinstall -y /tmp/jdk-8u161-linux-x64.rpm"
  end

  def install_nmon
    if x("yum list installed | grep nmon") =~ /nmon/
      puts "nmon already installed"
      return
    end

    puts "Installing nmon"

    x "yum install -y nmon"
  end

  def install_jdbc_driver
    if x("ls /usr/share/java") =~ /mysql-connector-java\.jar/
      puts "JDBC driver already installed"
      return
    end

    puts "Installing JDBC driver - mysql-connector-java-5.1.45-bin.jar - in /usr/share/java"
    
    puts "Downloading JDBC driver"
    x "wget https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.45.tar.gz"
    x "tar -xzf mysql-connector-java-5.1.45.tar.gz"

    puts "Moving and renaming JDBC driver"
    x "mkdir /usr/share/java"
    x "mv mysql-connector-java-5.1.45/mysql-connector-java-5.1.45-bin.jar /usr/share/java/mysql-connector-java.jar"
    x "rm -rf mysql-connector-java-5.1.45*"
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
    x "yum install -y yum-utils"
    x "yum-config-manager --add-repo https://archive.cloudera.com/cm5/redhat/7/x86_64/cm/cloudera-manager.repo"
    puts "Installing cloudera-manager-daemons"
    x "yum install -y cloudera-manager-daemons"
    x "yum install -y cloudera-manager-server"

    puts "Verifying Cloudera Manager databases are configured properly"
    x "/usr/share/cmf/schema/scm_prepare_database.sh mysql cmserver cmserver_user #{@conf.mysql_cm_dbs_password}"

    puts "Starting cloudera-scm-server"
    x "systemctl start cloudera-scm-server"
  end

  def x(cmd, verbose=@conf.debug_mode)
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
    Net::SCP.upload!(@host,
                    @conf.user,
                    file_to_copy_path,
                    destination_path,
                    :ssh => { :password => @conf.password })
  end

  def upload(file_to_copy_path, destination_path)
  end

  def mysql(cmd)
    x "mysql -e \"#{cmd}\""
  end
end

mm = MiddleManager.new
mm.run

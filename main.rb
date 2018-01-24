require 'ostruct'
require 'net/ssh'
require 'net/scp'

class MiddleManager

  attr_reader :conf

  def initialize
    @conf = OpenStruct.new({
      user:                  'root',
      pass:                  'cloudera',
      hosts:                 [
        'jmichaels-mgmt-1.gce.cloudera.com',
        'jmichaels-mgmt-2.gce.cloudera.com',
        'jmichaels-mgmt-3.gce.cloudera.com',
        'jmichaels-mgmt-4.gce.cloudera.com',
        'jmichaels-mgmt-5.gce.cloudera.com',
      ],
      mysql_root_pass:       'VaT990mLJj',
      #mysql_slave_root_pass: '7r2gXNVS0R',
      mysql_slave_user_pass: 'r47XkHCgpn',
      mysql_cm_dbs_password: 'h1TqkGM3TH'
    })
  end

  def test_connection
    raise "Must connect as root." if @conf.user != 'root'

    @conf.hosts.each do |host|
      puts "Testing connection: ssh#{@conf.user}@#{host}"
      ssh = Net::SSH.start(host, @conf.user, password: @conf.password)
      result = ssh.exec!("hostname")
      raise "Could not connect to #{host}" unless result =~ /#{host}/
    end
  end

  def run
    hosts       = @conf.hosts
    first_node  = hosts[0]
    second_node = hosts[1]

    hosts.each do |host|
      puts "Configuring:  #{host}"
      ssh = Net::SSH.start(host, @conf.user, password: @conf.password)
      #set_swappiness(ssh, host)
      #disable_transparent_hugepage(ssh, host)
      #ensure_nscd_running(ssh, host)
      #ensure_ntpd_running(ssh, host)
    end

    puts "Moving on to first node, #{first_node}"

    ssh = Net::SSH.start(first_node, @conf.user, password: @conf.password)
    deploy_mysql_my_cnf(ssh, first_node, 'master')
    install_maria_db(ssh, first_node)
    install_jdk(ssh, first_node)
    mysql_secure_installation(ssh, first_node)
    setup_cm_dbs(ssh, first_node)

    puts "Configuring second node, #{second_node}"

    ssh = Net::SSH.start(second_node, @conf.user, password: @conf.password)
    deploy_mysql_my_cnf(ssh, second_node, 'slave')
    install_maria_db(ssh, second_node)
    mysql_secure_installation(ssh, second_node)

    mysql_replication_setup(first_node, second_node)

    install_cloudera_manager(ssh, first_node)
  end

  def set_swappiness(ssh, host)
    puts "Setting 'swappiness' to lowest possible value (1)."
    ssh.exec!("sh -c 'echo 1 > /proc/sys/vm/swappiness'")
    res = ssh.exec!("cat /proc/sys/vm/swappiness")
  end

  def disable_transparent_hugepage(ssh, host)
    thp_defrag_res = ssh.exec!("cat /sys/kernel/mm/transparent_hugepage/defrag")
    thp_res        = ssh.exec!("cat /sys/kernel/mm/transparent_hugepage/enabled")

    if thp_res =~ /\[never\]/ && thp_defrag_res =~ /\[never\]/
      puts "transparent_hugepage already disabled"
    else
      puts "Disabling transparent_hugepage"
      ssh.exec!("echo never > /sys/kernel/mm/transparent_hugepage/enabled")
      ssh.exec!("echo never > /sys/kernel/mm/transparent_hugepage/defrag")

      puts "Modifying /etc/rc.d/rc.local to disable transparent_hugepage on startup"
      rc_local_file = ssh.exec!("cat /etc/rc.d/rc.local")

      unless rc_local_file =~ /\/sys\/kernel\/mm\/transparent_hugepage\/defrag/
        puts "Adding 'echo never > /sys/kernel/mm/transparent_hugepage/defrag'"
        ssh.exec!("echo 'echo never > /sys/kernel/mm/transparent_hugepage/defrag' >> /etc/rc.d/rc.local")
      end

      unless rc_local_file =~ /\/sys\/kernel\/mm\/transparent_hugepage\/enabled/
        puts "Adding 'echo never > /sys/kernel/mm/transparent_hugepage/enabled'"
        ssh.exec!("echo 'echo never > /sys/kernel/mm/transparent_hugepage/enabled' >> /etc/rc.d/rc.local")
      end

      puts "Ensuring /etc/rc.d/rc.local is executable"
      ssh.exec!("chmod +x /etc/rc.d/rc.local")
    end
  end

  def ensure_nscd_running(ssh, host)
    res = ssh.exec!("service nscd status")
    raise "ERROR: nscd not running on #{host}" unless res =~ /active \(running\)/
  end

  def ensure_ntpd_running(ssh, host)
    res = ssh.exec!("service ntpd status")
    raise "ERROR: ntpd not running on #{host}" unless res =~ /active \(running\)/
  end

  def deploy_mysql_my_cnf(ssh, host, master_or_slave)
    if ssh.exec!("cat /etc/my.cnf") =~ /MiddleManager/
      puts "/etc/my.cnf already deployed"
    else
      puts "Deploying /etc/my.cnf"
      Net::SCP.upload!(host,
                      @conf.user,
                      "./files/mysql_#{master_or_slave}_config.my.cnf",
                      "/etc/my.cnf",
                      :ssh => { :password => @conf.password })

      puts "Removing /var/lib/mysql/ib_logfile*"
      ssh.exec!("rm -f /var/lib/mysql/ib_logfile*")
      restart_mysql(ssh, host)
    end
  end

  def install_maria_db(ssh, host)
    res = ssh.exec!("yum list installed | grep mariadb")
    if res =~ /mariadb-server/
      puts "MariaDB is already installed"
    else
      puts "Installing MariaDB (MySQL)"

      puts "yum install -y mariadb-server"
      puts ssh.exec!("yum install -y mariadb-server")

      puts "starting mariadb"
      ssh.exec!("systemctl start mariadb")
      ssh.exec!("systemctl enable mariadb")

      restart_mysql(ssh, host)

      puts "MariaDB install complete"
    end
  end

  def restart_mysql(ssh, host)
    puts "Restarting mariadb service"
    res = ssh.exec!("systemctl restart mariadb")
    if res.strip.length > 0
      puts "Error: \n"
      puts res.inspect
      raise "MariaDB restart failed on #{host}"
    end
  end

  def mysql_secure_installation(ssh, host)
    puts "Securing MySQL installation"

    # Make sure that NOBODY can access the server without a password
    ssh.exec!("mysql -e \"UPDATE mysql.user SET Password = PASSWORD('#{@conf.mysql_root_pass}') WHERE User = 'root'\"")
    # Kill the anonymous users
    ssh.exec!("mysql -e \"DROP USER ''@'localhost'\"")
    # Because our hostname varies we'll use some Bash magic here.
    ssh.exec!("mysql -e \"DROP USER ''@'$(hostname)'\"")
    # Kill off the demo database
    ssh.exec!("mysql -e \"DROP DATABASE test\"")
    # Make our changes take effect
    ssh.exec!("mysql -e \"FLUSH PRIVILEGES\"")

    ssh.exec!("echo [client] > ~/.my.cnf")
    ssh.exec!("echo user=root >> ~/.my.cnf")
    ssh.exec!("echo pass=#{@conf.mysql_root_pass} >> ~/.my.cnf")
  end

  def mysql_replication_setup(master_host, slave_host)
    ssh = Net::SSH.start(slave_host, @conf.user, password: @conf.password)
    if ssh.exec!("mysql -e \"SHOW SLAVE STATUS\\G\"") =~ /Waiting for master to send event/
      puts "MySQL replication is already working"
      return
    end

    puts "Configuring MySQL replication between #{master_host} and #{slave_host}"

    puts "Creating slave user"
    ssh = Net::SSH.start(master_host, @conf.user, password: @conf.password)
    ssh.exec!("mysql -e \"GRANT REPLICATION SLAVE ON *.* TO 'slave_user'@'%' IDENTIFIED BY '#{@conf.mysql_slave_user_pass}';\"")
    ssh.exec!("mysql -e \"SET GLOBAL binlog_format = 'ROW';\"")
    ssh.exec!("mysql -e \"FLUSH TABLES WITH READ LOCK;\"")
    master_status = ssh.exec!("mysql -e \"SHOW MASTER STATUS;\"")
    # master_status looks like:
    # "File\tPosition\tBinlog_Do_DB\tBinlog_Ignore_DB\nmysql_binary_log.000014\t2172\t\t\n"
    master_log_file = master_status.split("\n").last.split(" ").first
    master_log_pos  = master_status.split("\n").last.split(" ").last

    ssh.exec!("mysql -e \"UNLOCK TABLES;\"")

    puts "Configuring slave"
    ssh = Net::SSH.start(slave_host, @conf.user, password: @conf.password)
    ssh.exec!("mysql -e \"CHANGE MASTER TO MASTER_HOST='#{master_host}', MASTER_USER='slave_user', MASTER_PASSWORD='#{@conf.mysql_slave_user_pass}', MASTER_LOG_FILE='#{master_log_file}', MASTER_LOG_POS=#{master_log_pos};\"")
    ssh.exec!("mysql -e \"START SLAVE;\"") 
    puts ssh.exec!("mysql -e \"SHOW SLAVE STATUS\\G\"") 

    puts "MySQL replication setup complete"
  end

  def install_jdk(ssh, host)
    if ssh.exec!("yum list installed | grep jdk") =~ /jdk1\.8/
      puts "JDK for Java 8 already installed"
      return
    end

    puts "Installing JDK for Java 8"

    puts "SCPing JDK 8 RPM to server"
    Net::SCP.upload!(host,
                @conf.user,
                "./jdks/jdk-8u161-linux-x64.rpm",
                "/tmp/",
                :ssh => { :password => @conf.password })

    puts "Deploying /etc/profile.d/java.sh"
    Net::SCP.upload!(host,
                @conf.user,
                "./files/java.sh",
                "/etc/profile.d/java.sh",
                :ssh => { :password => @conf.password })

    puts "Installing JDK 8 RPM"
    puts ssh.exec!("yum localinstall -y /tmp/jdk-8u161-linux-x64.rpm")
  end

  def setup_cm_dbs(ssh, host)

    ssh.exec!("mysql -e \"CREATE DATABASE cmserver DEFAULT CHARACTER SET utf8;\"")
    ssh.exec!("mysql -e \"GRANT ALL on cmserver.* TO 'cmserveruser'@'%' IDENTIFIED BY '#{@conf.cm_dbs_password}';\"")
  end

  def install_cloudera_manager(ssh, host)
    ssh.exec!("yum-config-manager --add-repo https://archive.cloudera.com/cm5/redhat/7/x86_64/cm/cloudera-manager.repo")
    ssh.exec!("yum install -y cloudera-manager-daemons")
    ssh.exec!("yum install -y cloudera-manager-server")

    puts "Verifying Cloudera Manager databases are configured properly"
    puts ssh.exec!("/usr/share/cmf/schema/scm_prepare_database.sh mysql cmserver cmserveruser password")

    puts "Starting cloudera-scm-server"
    puts ssh.exec!("systemctl start cloudera-scm-server")
  end
end

mm = MiddleManager.new

#mm.test_connection
mm.run
#mm.mysql_replication_setup(mm.conf.hosts[0], mm.conf.hosts[1])
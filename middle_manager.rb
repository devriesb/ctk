class MiddleManager

  attr_reader :conf, :servers

  def initialize
    @conf = Config.load
    @servers = @conf.hostnames.map{ |hostname| Server.new(hostname) }
  end

  def run
    servers.each do |server|
      prep_server_for_cdh(server)
    end

    cm_host                = servers.find{ |svr| svr.hostname == @conf.cm.host }
    mysql_replication_host = servers.find{ |svr| svr.hostname == @conf.mysql_replication_host }

    install_cloudera_manager(cm_host)

    if @conf.mysql_replication_host
      configure_mysql_replication_server(server)
      mysql_replication_setup(@conf.cm.host, @conf.mysql_replication_host)
    end

    puts "Server is running at: http://#{@servers.first.hostname}:7180"
  end

  def prep_server_for_cdh(server)
    puts "Prepping #{server.hostname} for CDH"

    server.set_swappiness
    server.disable_transparent_hugepage
    server.install "ntp", "ntpd"
    server.install "nsc", "nscd"
    server.install_jdbc_driver
    server.install_jdk
    server.install_nmon
  end

  def install_cloudera_manager(server)
    puts "Configuring #{server.hostname} and installing Cloudera Manager"
    server.install_maria_db
    server.deploy_mysql_my_cnf('master')
    server.install_jdk
    server.mysql_secure_installation
    server.setup_cm_dbs
    server.install_cloudera_manager
  end

  def configure_mysql_replication_server(server)
    puts "Configuring #{server.hostname} for MySQL replication"
    server.install_maria_db
    server.deploy_mysql_my_cnf('slave')
    server.mysql_secure_installation
  end

  def mysql_replication_setup(master_host, slave_host)
    @ssh_connection = Net::SSH.start(slave_host, @conf.user, password: @conf.password)
    if slave_host.mysql("SHOW SLAVE STATUS\\G") =~ /Waiting for master to send event/
      puts "MySQL replication is already working"
      return
    end

    puts "Configuring MySQL replication between #{master_host} and #{slave_host}"

    puts "Creating slave user"
    master_host.mysql "GRANT REPLICATION SLAVE ON *.* TO 'slave_user'@'%' IDENTIFIED BY '#{@conf.mysql_slave_user_pass}';"
    master_host.mysql "SET GLOBAL binlog_format = 'ROW';"
    master_host.mysql "FLUSH TABLES WITH READ LOCK;"
    master_status = master_host.mysql "SHOW MASTER STATUS;"

    # master_status looks like:
    # "File\tPosition\tBinlog_Do_DB\tBinlog_Ignore_DB\nmysql_binary_log.000014\t2172\t\t\n"
    master_log_file = master_status.split("\n").last.split(" ").first
    master_log_pos  = master_status.split("\n").last.split(" ").last

    master_host.mysql "UNLOCK TABLES;"

    puts "Configuring slave"
    slave_host.mysql "CHANGE MASTER TO MASTER_HOST='#{master_host}', MASTER_USER='slave_user', MASTER_PASSWORD='#{@conf.mysql_slave_user_pass}', MASTER_LOG_FILE='#{master_log_file}', MASTER_LOG_POS=#{master_log_pos};"
    slave_host.mysql "START SLAVE;"
    slave_host.mysql "SHOW SLAVE STATUS\\G"

    puts "MySQL replication setup complete"
  end
end
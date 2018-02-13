class ClusterInstaller

  attr_reader :servers

  def initialize
    @servers = $conf.hostnames.map{ |hostname| Server.new(hostname) }

    @cm_server                = servers.find{ |svr| svr.hostname == $conf.cm.host }
    @mysql_replication_server = servers.find{ |svr| svr.hostname == $conf.mysql_replication_host }
  end

  def run
    configure_all_servers_for_cdh
    install_cloudera_manager
    maybe_set_up_mysql_replication

    puts "Server is running at: http://#{@servers.first.hostname}:7180"
  end

  def configure_all_servers_for_cdh
    servers.each do |server|
      configure_server_for_cdh(server)
    end
  end

  def configure_server_for_cdh(server)
    puts "Prepping #{server.hostname} for CDH"

    server.set_swappiness
    server.disable_transparent_hugepage
    server.install "ntp"
    server.service('ntpd').start_and_enable
    server.install "nsc"
    server.service('nscd').start_and_enable
    server.install_jdbc_driver
    server.install_jdk
    server.install "nmon"
  end

  def install_cloudera_manager
    puts "Configuring #{@cm_server.hostname} and installing Cloudera Manager"
    @cm_server.install "mariadb-server"
    @cm_server.service('mariadb').enable
    @cm_server.deploy_mysql_my_cnf('master')
    @cm_server.service('mariadb').restart
    @cm_server.install_jdk
    MysqlBoss.secure_installation(@cm_server)
    MysqlBoss.setup_cm_dbs(@cm_server)
    @cm_server.install_cloudera_manager
  end

  def maybe_set_up_mysql_replication
    if $conf.mysql_replication_host
      configure_mysql_replication_server(@mysql_replication_server)
      MysqlBoss.mysql_replication_setup(@cm_server, @mysql_replication_server)
    else
      puts "Skipping MySQL replication setup"
    end
  end

  def configure_mysql_replication_server(server)
    puts "Configuring #{server.hostname} for MySQL replication"
    server.install "mariadb-server"
    server.service('mariadb').enable
    server.deploy_mysql_my_cnf('slave')
    server.service('mariadb').restart
    MysqlBoss.secure_installation(server)
  end
end
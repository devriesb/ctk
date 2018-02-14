class ClusterInstaller

  attr_reader :boxes

  def initialize
    @boxes = $conf.hostnames.map{ |hostname| Box.new(hostname) }

    @cm_box                = boxes.find{ |svr| svr.hostname == $conf.cm.host }
    @mysql_replication_box = boxes.find{ |svr| svr.hostname == $conf.mysql_replication_host }
  end

  def run
    configure_all_boxes_for_cdh
    install_cloudera_manager
    maybe_set_up_mysql_replication

    puts "Box is running at: http://#{@boxes.first.hostname}:7180"
  end

  def configure_all_boxes_for_cdh
    boxes.each do |box|
      configure_box_for_cdh(box)
    end
  end

  def configure_box_for_cdh(box)
    puts "Prepping #{box.hostname} for CDH"

    box.set_swappiness
    box.disable_transparent_hugepage
    box.install "ntp"
    box.service('ntpd').start_and_enable
    box.install "nsc"
    box.service('nscd').start_and_enable
    box.install_jdbc_driver
    box.install_jdk
    box.install "nmon"
  end

  def install_cloudera_manager
    puts "Configuring #{@cm_box.hostname} and installing Cloudera Manager"
    @cm_box.install "mariadb-server"
    @cm_box.service('mariadb').enable
    @cm_box.deploy_mysql_my_cnf('master')
    @cm_box.service('mariadb').restart
    @cm_box.install_jdk
    MysqlBoss.secure_installation(@cm_box)
    MysqlBoss.setup_cm_dbs(@cm_box)
    @cm_box.install_cloudera_manager
  end

  def maybe_set_up_mysql_replication
    if $conf.mysql_replication_host
      configure_mysql_replication_box(@mysql_replication_box)
      MysqlBoss.mysql_replication_setup(@cm_box, @mysql_replication_box)
    else
      puts "Skipping MySQL replication setup"
    end
  end

  def configure_mysql_replication_box(box)
    puts "Configuring #{box.hostname} for MySQL replication"
    box.install "mariadb-server"
    box.service('mariadb').enable
    box.deploy_mysql_my_cnf('slave')
    box.service('mariadb').restart
    MysqlBoss.secure_installation(box)
  end
end
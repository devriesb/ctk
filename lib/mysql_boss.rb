class MysqlBoss
  def self.setup_cm_dbs(box)
    puts "Creating databases/users for Cloudera Manager"
    ['cmserver', 'hive', 'amon', 'rman', 'oozie', 'hue'].each do |db_name|
      puts "Creating #{db_name} database and #{db_name}_user user."

      box.mysql "CREATE DATABASE #{db_name} DEFAULT CHARACTER SET utf8;"
      box.mysql "DROP USER IF EXISTS '#{db_name}_user'@'%';"
      box.mysql "GRANT ALL on #{db_name}.* TO '#{db_name}_user'@'%' IDENTIFIED BY '#{$conf.mysql_cm_dbs_password}';"
    end
  end

  def self.mysql_replication_setup(master_box, slave_box)
    if slave_box.mysql("SHOW SLAVE STATUS\\G") =~ /Waiting for master to send event/
      puts "MySQL replication is already working"
      return
    end

    puts "Configuring MySQL replication between #{master_box} and #{slave_box}"

    puts "Creating slave user"
    master_box.mysql "GRANT REPLICATION SLAVE ON *.* TO 'slave_user'@'%' IDENTIFIED BY '#{$conf.mysql_slave_user_pass}';"
    master_box.mysql "SET GLOBAL binlog_format = 'ROW';"
    master_box.mysql "FLUSH TABLES WITH READ LOCK;"
    master_status = master_box.mysql "SHOW MASTER STATUS;"

    # master_status looks like:
    # "File\tPosition\tBinlog_Do_DB\tBinlog_Ignore_DB\nmysql_binary_log.000014\t2172\t\t\n"
    master_log_file = master_status.split("\n").last.split(" ").first
    master_log_pos  = master_status.split("\n").last.split(" ").last

    master_box.mysql "UNLOCK TABLES;"

    puts "Configuring slave"
    slave_box.mysql "CHANGE MASTER TO master_server='#{master_server}', MASTER_USER='slave_user', MASTER_PASSWORD='#{$conf.mysql_slave_user_pass}', MASTER_LOG_FILE='#{master_log_file}', MASTER_LOG_POS=#{master_log_pos};"
    slave_box.mysql "START SLAVE;"
    slave_box.mysql "SHOW SLAVE STATUS\\G"

    puts "MySQL replication setup complete"
  end

  def self.secure_installation(box)
    puts "Securing MySQL installation"

    # Set root password
    box.mysql "UPDATE mysql.user SET Password = PASSWORD('#{$conf.mysql_root_pass}') WHERE User = 'root'"

    # Remove anonymous users
    box.mysql "DROP USER ''@'localhost'"

    # Because our hostname varies we'll use some Bash magic here.
    box.mysql "DROP USER ''@'$(hostname)'"

    # Remove the test database
    box.mysql "DROP DATABASE test"

    # Make our changes take effect
    box.mysql "FLUSH PRIVILEGES"

    # Automate mysql logins for the root user via ~/.my.cnf file
    box.cmd "echo [client] > ~/.my.cnf"
    box.cmd "echo user=root >> ~/.my.cnf"
    box.cmd "echo pass=#{$conf.mysql_root_pass} >> ~/.my.cnf"

    # Lock it down, only root should see this file
    box.cmd "chmod 600 ~/.my.cnf"
  end
end
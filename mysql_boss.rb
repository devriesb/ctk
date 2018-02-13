class MysqlBoss
  
  def setup_cm_dbs
    puts "Creating databases/users for Cloudera Manager"
    ['cmserver', 'hive', 'amon', 'rman', 'oozie', 'hue'].each do |db_name|
      puts "Creating #{db_name} database and #{db_name}_user user."

      mysql "CREATE DATABASE #{db_name} DEFAULT CHARACTER SET utf8;"
      mysql "DROP USER IF EXISTS '#{db_name}_user'@'%';"
      mysql "GRANT ALL on #{db_name}.* TO '#{db_name}_user'@'%' IDENTIFIED BY '#{@conf.mysql_cm_dbs_password}';"
    end
  end

end
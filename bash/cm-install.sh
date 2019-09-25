#! /bin/bash


### VARIABLES THAT SHOULD BE SET ###
MYSQL_ROOT_PASS=rootPass
MYSQL_CM_DBS_PASS=dbPass
#source configuration.properties



### Functions go here ###


function secure_installation {

    echo "Securing MySQL installation"

    # Set root password
    mysql -e "UPDATE mysql.user SET Password = PASSWORD('$MYSQL_ROOT_PASS') WHERE User = 'root'"

    # Remove anonymous users
    mysql -e "DROP USER ''@'localhost'"

    # Because our hostname varies we'll use some Bash magic here.
    mysql -e "DROP USER ''@'$(hostname)'"

    # Remove the test database
    mysql -e "DROP DATABASE test"

    # Make our changes take effect
    mysql -e "FLUSH PRIVILEGES"

    # Automate mysql logins for the root user via ~/.my.cnf file
    echo [client] > ~/.my.cnf
    echo user=root >> ~/.my.cnf
    echo pass=$MYSQL_ROOT_PASS >> ~/.my.cnf
   
    # Lock it down, only root should see this file
    chmod 600 ~/.my.cnf
}

function setup_db {
    echo "Creating $1 database and $1 user."
    mysql -e "CREATE DATABASE $1 DEFAULT CHARACTER SET utf8;"
    mysql -e "GRANT ALL on $1.* TO '$1'@'%' IDENTIFIED BY '$MYSQL_CM_DBS_PASS';"
}

function  setup_cm_dbs {
    echo "Creating databases/users for Cloudera Manager"
    setup_db cloudera_manager
    setup_db hive
    setup_db activity_monitor
    setup_db reports_manager
    setup_db oozie
    setup_db hue
    setup_db navigator_audit
    setup_db navigator_meta
}

function install {
    yum -y install $1
}

function start {
    systemctl start $1
}

function restart {
    systemctl restart $1
}

function enable {
    systemctl enable $1
}

function start_and_enable {
    start $1
    enable $1
}


function install_jdbc_driver {
    echo "Installing JDBC driver - mysql-connector-java-5.1.45-bin.jar - in /usr/share/java"
    echo "Downloading JDBC driver"
    wget https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.45.tar.gz
    tar -xzf mysql-connector-java-5.1.45.tar.gz
    
    echo "Moving and renaming JDBC driver"
    mkdir -p /usr/share/java
    mv mysql-connector-java-5.1.45/mysql-connector-java-5.1.45-bin.jar /usr/share/java/mysql-connector-java.jar
    rm -rf mysql-connector-java-5.1.45*
}

function install_jdk {
    yum -y install java-1.8.0
}


function set_swappiness {
    echo $1 /proc/sys/vm/swappiness
}

function disable_transparent_hugepage {
    echo 'echo never > /sys/kernel/mm/transparent_hugepage/defrag' >> /etc/rc.d/rc.local  
    echo 'echo never > /sys/kernel/mm/transparent_hugepage/enabled' >> /etc/rc.d/rc.local
    chmod +x /etc/rc.d/rc.local
    /etc/rc.d/rc.local
}

function do_basic_setup {
    set_swappiness 1
    disable_transparent_hugepage
    install ntp
    start_and_enable ntpd
    install nsc
    start_and_enable nscd
    install_jdbc_driver
    install_jdk
    install nmon
    install vim
}

function deploy_mysql_my_cnf_master { 
    echo "Deploying /etc/my.cnf"
    wget https://raw.githubusercontent.com/devriesb/ctk/master/files/mysql_master_config.my.cnf -O /etc/my.cnf

    echo "Removing /var/lib/mysql/ib_logfile*"
    rm -f /var/lib/mysql/ib_logfile*
}

function install_cloudera_manager {

    echo "Configuring and installing Cloudera Manager"
    install mariadb-server
    enable mariadb
    deploy_mysql_my_cnf_master
    restart mariadb
    
    secure_installation
    setup_cm_dbs

    install yum-utils

    yum-config-manager --add-repo https://archive.cloudera.com/cm5/redhat/7/x86_64/cm/cloudera-manager.repo
    #yum-config-manager --add-repo https://https://archive.cloudera.com/cm6/6.3.0/redhat7/yum/cloudera-manager.repo

    install cloudera-manager-daemons
    install cloudera-manager-server

    echo "Verifying Cloudera Manager databases are configured properly"
    /usr/share/cmf/schema/scm_prepare_database.sh mysql cloudera_manager cloudera_manager $MYSQL_CM_DBS_PASS

    start_and_enable cloudera-scm-server
    
    echo "Cloudera Manager is running at: http://$(hostname):7180"
}

do_basic_setup

# comment "install_cloudera_manager" out for secondary boxes...
install_cloudera_manager






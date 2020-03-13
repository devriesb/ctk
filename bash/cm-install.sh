#! /bin/bash

### VARIABLES THAT SHOULD BE SET ###
MYSQL_ROOT_PASS=rootPass
MYSQL_CM_DBS_PASS=dbPass

function setup_passwordless_ssh() {
  mkdir -p /root/.ssh
  echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC4qzr4vbFmj1MtholcUEU/RmugsOEXzAzUUH9ymbZfKEc9algPBep0Krcph1Sn0pfowspVTfhZAL11JKcN/+EwbbXvtBJV+M/aBNNzmCGJ/4Seqgt3aaaOGiaO0YnLwk+rPKCjlhLmmi6HM/rYQha3H+2S3nL89YWV+LXzigtwAfDBM4qvGPFZldpZz2JQFsr0KfCnOPrKnoE91ZHoYdgpDo+ryZsk71RrI5nFkQxLq/fjvPPt8RHBO6FdcFptpAwt8iHYn7sb2NzZeQ5JxhJV+d7MqaJNlADtJquAv8RfGArsdPR6GR2vvDzK8f7FM96SPhwHbKHHJGBv23o3WqER bdevries_cloudcat" >> /root/.ssh/authorized_keys
  chmod 700 /root/.ssh; chmod 640 /root/.ssh/authorized_keys
}

function yumClean() {
  yum clean packages
  yum clean metadata
  yum clean headers
  yum clean all
}

function secure_installation() {

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
  echo [client] >~/.my.cnf
  echo user=root >>~/.my.cnf
  echo pass=$MYSQL_ROOT_PASS >>~/.my.cnf

  # Lock it down, only root should see this file
  chmod 600 ~/.my.cnf
}

function setup_db() {
  echo "Creating $1 database and $1 user."
  mysql -e "CREATE DATABASE $1 DEFAULT CHARACTER SET utf8;"
  mysql -e "GRANT ALL on $1.* TO '$1'@'%' IDENTIFIED BY '$MYSQL_CM_DBS_PASS';"
}

function backup_db() {
  mysqldump --databases "$1" --host=localhost  -u "$1" -p > "$HOME"/"$1"-backup-"$(date +%F)"-CM5.15.sql
}

function backup_cm_dbs() {
  echo "Backup databases for Cloudera Manager"
  backup_db cloudera_manager
  backup_db hive
  backup_db activity_monitor
  backup_db reports_manager
  backup_db oozie
  backup_db hue
  backup_db navigator_audit
  backup_db navigator_meta
}

function setup_cm_dbs() {
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

function start_and_enable() {
  systemctl start "$1"
  systemctl enable "$1"
}

function downloadNiFiParcels() {
  wget http://archive.cloudera.com/CFM/csd/1.0.0.0/NIFI-1.9.0.1.0.0.0-90.jar
  wget http://archive.cloudera.com/CFM/csd/1.0.0.0/NIFICA-1.9.0.1.0.0.0-90.jar
  wget http://archive.cloudera.com/CFM/csd/1.0.0.0/NIFIREGISTRY-0.3.0.1.0.0.0-90.jar
  chown cloudera-scm:cloudera-scm NIFI*.jar
  chmod 644 NIFI*.jar
  mkdir -p /opt/cloudera/csd
  mv NIFI*.jar /opt/cloudera/csd
}

function install_jdbc_driver() {
  echo "Installing JDBC driver - mysql-connector-java-5.1.45-bin.jar - in /usr/share/java"
  echo "Downloading JDBC driver"
  wget https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.45.tar.gz
  tar -xzf mysql-connector-java-5.1.45.tar.gz

  echo "Moving and renaming JDBC driver"
  mkdir -p /usr/share/java
  mv mysql-connector-java-5.1.45/mysql-connector-java-5.1.45-bin.jar /usr/share/java/mysql-connector-java.jar
  rm -rf mysql-connector-java-5.1.45*
}

function set_swappiness() {
  echo "$1" >/proc/sys/vm/swappiness
}

function disable_transparent_hugepage() {
  {
    grep -v "exit 0" /etc/rc.d/rc.local
    echo 'echo never > /sys/kernel/mm/transparent_hugepage/defrag'
    echo 'echo never > /sys/kernel/mm/transparent_hugepage/enabled'
    echo 'exit 0'
  } >/etc/rc.d/rc.local.tmp
  mv -f /etc/rc.d/rc.local.tmp /etc/rc.d/rc.local
  chmod +x /etc/rc.d/rc.local
  /etc/rc.d/rc.local
}

function do_basic_setup() {
  setup_passwordless_ssh
  set_swappiness 1
  disable_transparent_hugepage
  yum -y install ntp
  start_and_enable ntpd
  yum -y install nsc
  start_and_enable nscd
  install_jdbc_driver
  yum -y install nmon
  yum -y install vim

  yum -y install python
  yum -y install yum-utils
  yum -y install xauth

  yum -y install krb5-workstation
  yum -y install krb5-libs
}

function setupDB() {
  yum -y install mariadb-server
  systemctl stop mariadb

  echo "Deploying /etc/my.cnf"
  wget https://raw.githubusercontent.com/devriesb/ctk/master/files/mysql_master_config.my.cnf -O /etc/my.cnf

  echo "Removing /var/lib/mysql/ib_logfile*"
  rm -f /var/lib/mysql/ib_logfile*

  systemctl enable mariadb
  systemctl start mariadb

  secure_installation
  setup_cm_dbs
}

function install_java() {

  yum-config-manager --add-repo "$YUM_REPO"
  yum -y install "$JAVA_PACKAGE"
  JAVA_PATH=$(find / -name "java" -path "*/bin/*" | grep -v jre)
  JAVA_HOME=${JAVA_PATH//"/bin/java"/}
  echo "JAVA_HOME=$JAVA_HOME" >>/etc/profile
  echo "PATH=$JAVA_HOME/bin:$PATH" >>/etc/profile
  source /etc/profile
}

function install_freeipa() {

  setup_passwordless_ssh

  echo "Installing FreeIPA (will still need to be set up...)"

  yum -y update nss
  yum -y install freeipa-server
  yum -y install firewalld
  systemctl start firewalld
  firewall-cmd --add-service=freeipa-ldap --add-service=freeipa-ldap --permanent
  firewall-cmd --reload
}

function install_cloudera_manager() {

  yum-config-manager --add-repo "$YUM_REPO"

  do_basic_setup
  setupDB
  install_java

  yum -y install cloudera-manager-daemons
  yum -y install cloudera-manager-agent
  yum -y install cloudera-manager-server

  # enable auto-TLS
  # TODO make this optional... remove for now
  #export JAVA_HOME=$JAVA_HOME
  #/opt/cloudera/cm-agent/bin/certmanager setup --configure-services --override ca_dn="CN=$(hostname)"
  #cp /var/lib/cloudera-scm-server/certmanager/trust-store/cm-auto-global_cacerts.pem /tmp/cm-cacerts.pem

  echo "Verifying Cloudera Manager databases are configured properly"
  $PREPARE_DB_SCRIPT mysql cloudera_manager cloudera_manager $MYSQL_CM_DBS_PASS

  start_and_enable cloudera-scm-server

  echo "Cloudera Manager is running at: http://$(hostname):7180"

  #install_freeipa
}

function install_cloudera_agent_6() {

  echo "Installing Cloudera Agent"

  YUM_REPO="https://archive.cloudera.com/cm6/6.3.0/redhat7/yum/cloudera-manager.repo"
  JAVA_PACKAGE="oracle-j2sdk1.8"
  yum-config-manager --add-repo "$YUM_REPO"

  do_basic_setup
  setupDB
  install_java

  yum -y install cloudera-manager-agent

  echo "Cloudera Agent installed"
}

function install_cloudera_agent_6_1() {

  echo "Installing Cloudera Agent"

  YUM_REPO="https://archive.cloudera.com/cm6/6.1.0/redhat7/yum/cloudera-manager.repo"
  JAVA_PACKAGE="oracle-j2sdk1.8"
  yum-config-manager --add-repo "$YUM_REPO"

  do_basic_setup
  setupDB
  install_java

  yum -y install cloudera-manager-agent

  echo "Cloudera Agent installed"
}

function install_cloudera_manager_5() {
  echo "Configuring and installing Cloudera Manager 5"
  YUM_REPO="https://archive.cloudera.com/cm5/redhat/7/x86_64/cm/cloudera-manager.repo"
  JAVA_PACKAGE="oracle-j2sdk1.7"
  PREPARE_DB_SCRIPT=/usr/share/cmf/schema/scm_prepare_database.sh
  install_cloudera_manager
}

function install_cloudera_manager_5() {
  echo "Configuring and installing Cloudera Manager 5"
  YUM_REPO="https://archive.cloudera.com/cm5/redhat/7/x86_64/cm/cloudera-manager.repo"
  JAVA_PACKAGE="oracle-j2sdk1.7"
  PREPARE_DB_SCRIPT=/usr/share/cmf/schema/scm_prepare_database.sh
  install_cloudera_manager
}

function install_cloudera_manager_6() {
  echo "Configuring and installing Cloudera Manager 6"
  YUM_REPO="https://archive.cloudera.com/cm6/6.3.0/redhat7/yum/cloudera-manager.repo"
  JAVA_PACKAGE="oracle-j2sdk1.8"
  PREPARE_DB_SCRIPT=/opt/cloudera/cm/schema/scm_prepare_database.sh
  downloadNiFiParcels
  install_cloudera_manager
}


function install_cloudera_manager_6_1() {
  echo "Configuring and installing Cloudera Manager 6"
  YUM_REPO="https://archive.cloudera.com/cm6/6.1.0/redhat7/yum/cloudera-manager.repo"
  JAVA_PACKAGE="oracle-j2sdk1.8"
  PREPARE_DB_SCRIPT=/opt/cloudera/cm/schema/scm_prepare_database.sh
  downloadNiFiParcels
  install_cloudera_manager
}
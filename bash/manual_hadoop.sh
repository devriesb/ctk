#! /bin/bash

yum -y install java-1.8.0-openjdk

export JAVA_HOME=$(find / -name "java-1.8.0-openjdk*" | xargs -I possibleLocation find possibleLocation -name "jre")

CDH5_YUM_REPO=$(
  cat <<EOF
[cdh5-repo]
name=cdh5-repo
baseurl=https://archive.cloudera.com/cdh5/redhat/7/x86_64/cdh/5.16.2/
enabled=1
gpgcheck=0
EOF
)

echo "$CDH5_YUM_REPO" >/etc/yum.repos.d/cdh5.repo

yuum -y install hadoop

# Create HDFS directories
mkdir /dfs
mkdir -p /opt/hostname/dfs
chown hadoop:users /dfs
chown hadoop:users /opt/hostname
chmod -R 775 /df
chmod -R 755 /opt/hostname

# Create MapReduce directories
mkdir  /usr/lib/hadoop-yarn/logs/
mkdir  /usr/lib/hadoop-yarn/logs/userlogs
chmod -R 777  /usr/lib/hadoop-yarn/logs/

# copy config files

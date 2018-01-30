# BEFORE GITHUB
- Delete git history
- Delete passwords
- Delete server names

# Middle Manager

## What is Does:

Ruby script for preparing a Hadoop cluster and installing Cloudera Manager on CentOS 7.4 servers

## How to Install:

- curl -sSL https://get.rvm.io | bash -s stable
- rvm install ruby 2.3.0
- gem install net-ssh
- gem install net-scp
- download jdk-8u161-linux-x64.rpm from Oracle and put it in jdks/ directory

## How to Run It:

- `./run.sh`

## TODO:

- Dedicated config class which does not get committed to git, example config class which does
- Better logging - 'do' method which logs the command being run, says when it starts, when it ends 
  - should accept the 'ssh' object/connection
- Deploy JDK to all servers, by scping it from the first server
- Look at # of hosts, and setup servers differently, based on how the roles will be distributed
  - i.e. if 5 hosts, assume 1 master, 1 utility/edge, and 3 workers
    - if 10, spread them out more
    - Etc...
- Organize it to be more declarative
  - List packages in config
    - Then have an install_packages function
- Refactor 
  - Methods should be shorter, self documentation
- Config script
  - Runs the first time
    - Asks for host name / pattern
    - Ask which host you want to install CM on
    - Asks if you want to do MySQL replication
      - if yes Asks which server to install it on
- Look into running commands asynchronously, to speed up the process
  - Each server setup should be able to execute independently

# Middle Manager

## What is Does:

Ruby script for preparing a Hadoop cluster and installing Cloudera Manager on CentOS 7.4 boxes

## What it can do:

### Build out a hadoop cluster from scratch with Cloudera Manager installed:

```bash

# Create the real config file
cp config.example.rb config.rb

# Edit it, adding the hostnames of your cluster boxes and ssh credentials
vim config.rb

# Let it rip!
./install.rb
``` 

### Launch an interactive shell for managing your cluster

```bash

cd workspace/middle_manager
./shell.sh

```

```ruby

s = Box.all
s.count
s.first
s.map(&:hostname)
s.first.service('mariadb').status
s.first.service('sshd').status
s.first.install('mariadb-server')
Box.all.each{ |s| s.service('ntpd').start_and_enable }
cm = Box.find('cm')
cm.service('cloudera-scm-server').status

```

## How to Install:

- curl -sSL https://get.rvm.io | bash -s stable
- rvm install ruby 2.3.0
- gem install bundler
- bundle install

## How to Run It:

- `./install.sh`
- `./shell.sh`

## Warnings

- Oracle frequently changes the link to the Java 8 JDK download, you may have to update it in the config file

## TODO:

- Dedicated config class which does not get committed to git, example config class which does
- Better logging - 'do' method which logs the command being run, says when it starts, when it ends 
  - should accept the 'ssh' object/connection
- Deploy JDK to all boxes, by scping it from the first box
- Look at # of hosts, and setup boxes differently, based on how the roles will be distributed
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
      - if yes Asks which box to install it on
- Look into running commands asynchronously, to speed up the process
  - Each box setup should be able to execute independently
- Logo:  Something like this, but holding a ruby in trunk   https://www.google.com/search?q=elephant+face+drawing&source=lnms&tbm=isch&sa=X&ved=0ahUKEwic74_Z-qXZAhVJ8IMKHWZODvUQ_AUICigB&biw=1680&bih=930#imgrc=8wEvwIiMycWciM:

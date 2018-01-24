Install:
- curl -sSL https://get.rvm.io | bash -s stable
- rvm install ruby 2.3.0
- gem install net-ssh
- gem install net-scp
- download jdk-8u161-linux-x64.rpm from Oracle and put it in jdks/ directory

TODO:
- Dedicated config class which does not get committed to git, example config class which does
- Better logging - 'do' method which logs the command being run, says when it starts, when it ends 
  - should accept the 'ssh' object/connection

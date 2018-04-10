# Cluster Toolkit (CTK)

Set up a CDH Hadoop cluster with Cloudera Manager installed in < 5 minutes.

Manage your Hadoop cluster with this suite of command line tools.

_Tested on CentOS 7.4_

## What it can do:

### Properly configure your fresh servers for CDH, then install Cloudera Manager:

```bash

# Create the real config file
cp config.example.rb config.rb

# Edit it, adding the hostnames of your cluster boxes and ssh credentials
vim config.rb

# Let it rip!
./ctk install

# In ~5 minutes, it should output a message that says:
"Cloudera Manager is running at: http://your-cm-host.com:7180"

```

### Run a command on all of your servers in concurrent batches

```bash

./ctk run "cat /proc/meminfo"
./ctk run "yum install -y ntp"

```

### Launch an interactive ruby shell for easy management your cluster nodes

```bash

./ctk shell

```

This "interactive shell" is just Pry's debugging feature, with a breakpoint that triggers after the codebase is loaded.  We'll make it prettier soon.

```ruby
[1] pry(main)>

# Get a collection of all the servers in your cluster
> boxes = Box.all

# This returns a BoxGroup, which is just a Ruby Array with some additional features
> boxes.count

# You can treat it like a normal array
> boxes.each{ |box| box.cmd("ls /tmp") }
> boxes.first.cmd("ls /tmp")
> boxes.map(&:hostname)

# You can also run commands on all boxes concurrently
#
# This will as many concurrent processes as you have available CPU cores
# i.e. - If you have an 4 core processor with hyperthreading, it will operate in batches of 8
> boxes.cmd_all("yum install -y ntp")

# Or, you can concurrently run a set of instructions on all boxes
> boxes.each_concurrently do |box|
>   box.install("ntp")
>   box.service("ntp").start
>   box.service("ntp").enable
>   box.cmd("mkdir /tmp/tps_reports")
> end

# You can get the Cloudera Manager host like this:
Box.find('cm')

# Or, you can do it like this:
boxes.find{ |svr| svr.hostname == $conf.cm.host }
```

## How to Install:

### Install Ruby

(Skip this if you already have Ruby 2.0.0+ installed)

#### Option 1:  Install Ruby with Yum

```bash

yum install -y ruby

```

#### Option 2:  Install Ruby with RVM (Ruby Version Manager)

This is more complex, but gives you the ability to maintain different versions of Ruby on the same system.  If you don't need that feature, just do option 1.

```bash

# Install RVM (Ruby version manager)
curl -sSL https://get.rvm.io | bash -s stable

# Install Ruby
rvm install ruby 2.3.0

```

### Install Bundler

Bundler manages Ruby libraries and project dependencies

```bash

gem install bundler

```

### Clone the CTK Project and Install Dependencies 

```bash

cd ~

# Clone it to either your local machine, or a node on your cluster
git clone https://github.com/jmichaels/ctk.git

cd ctk

# Use Bundler to install the dependencies
bundle install

# The `ctk` executable to your path so you can call it from anywhere
echo export PATH=\"\$PATH:\$HOME/ctk\" >> ~/.bashrc
```



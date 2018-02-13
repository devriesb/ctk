require 'ostruct'
require 'net/ssh'
require 'net/scp'
require 'pry'
require './config'
require './lib/service'
require './lib/server'
require './lib/mysql_boss'
require './lib/cluster_installer'
require './lib/cm_api'

$conf = Config.load

# Get the command line arguments
mode = ARGV[0].chomp

if mode == 'install'
  ClusterInstaller.new.run
elsif mode == 'shell'
  binding.pry
else
  "Valid arguments are 'install' and 'shell'"
end
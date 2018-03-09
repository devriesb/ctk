require 'ostruct'
require 'net/ssh'
require 'net/scp'
require 'pry'
require 'parallel'
require './config'
require './lib/service'
require './lib/box'
require './lib/box_group'
require './lib/mysql_boss'
require './lib/cluster_installer'
require './lib/cm_api'

$conf = Config.load
$app_directory = Dir.pwd
$running_in_parallel = false

# Get the command line arguments
mode = ARGV[0].chomp
cmd = ARGV[1] ? ARGV[1].chomp : nil

if mode == 'install'
  ClusterInstaller.new.run
elsif mode == 'shell'
  binding.pry
elsif mode == 'run'
  puts "Running #{cmd} on all boxes"
  box_group = Box.all
  box_group.cmd_all(cmd)
else
  "Valid arguments are 'install' and 'shell'"
end

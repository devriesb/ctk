require 'ostruct'
require 'net/ssh'
require 'net/scp'
require 'pry'
require './service'
require './server'
require './config'
require './middle_manager'

mm = MiddleManager.new
mm.run

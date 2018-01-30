# XXX Very incomplete
# 
# This is an attempt to make a version of this script which could work without adding any gems.
# CDH includes a version of JRuby by default, and it would be great if we could get this
# to work with that out of the box.

class MiddleManager
  attr_reader :conf

  def initialize
    @conf = OpenStruct.new({
      user:                     'root',
      pass:                     'cloudera',
      hosts:                    (1..5).map{ |n| "jmichaels-#{n}.gce.cloudera.com"},
      mysql_root_pass:          'VaT990mLJj',
      mysql_slave_user_pass:    'r47XkHCgpn',
      mysql_cm_dbs_password:    'h1TqkGM3TH',
      cloudera_manager_host:    'jmichaels-1.gce.cloudera.com',
      mysql_replication_host:   nil,
      jdk_rpm_path:             './jdks/jdk-8u161-linux-x64.rpm',
      debug_mode:               true
    })

    @ssh_connection = nil
  end

  def test_connection
    raise "Must connect as root." if @conf.user != 'root'

    puts "Testing connection to hosts"

    @conf.hosts.each do |host|
      puts "Testing connection: ssh #{@conf.user}@#{host}"
      @ssh_connection = Net::SSH.start(host, @conf.user, password: @conf.password)
      result = x "hostname"
      raise "Could not connect to #{host}" unless result =~ /#{host}/
    end
  end

  def x(cmd, verbose=@conf.debug_mode)
    start_time = Time.now
    puts "BEGIN: #{cmd}"

    if verbose
      #result = @ssh_connection.exec!(cmd)
      result = `ssh #{@conf.user}@#{@host} #{cmd}`
      puts result
    else
      #result = @ssh_connection.exec!(cmd)
      result = `ssh #{cmd}`
    end

    end_time = Time.now
    duration = end_time - start_time
    puts "END (#{duration}s) \n\n"

    result
  end
end

class Service
  attr_reader :name, :server

  def initialize(name, server)
    @name = name
    @server = server
  end

  def status
    server.run("systemctl status #{name}")
  end

  def stop
    server.run("systemctl stop #{name}")
  end

  def start
    res = server.run("systemctl start #{name}")

    if res.strip.length > 0
      puts "Error: \n"
      puts res.inspect
      raise "#{name} start failed on #{server.hostname}"
    end

    res
  end

  def restart
    res = server.run("systemctl restart #{name}")

    if res.strip.length > 0
      puts "Error: \n"
      puts res.inspect
      raise "#{name} restart failed on #{server.hostname}"
    end

    res
  end

  def enable
    server.run("systemctl enable #{name}")
  end

  def start_and_enable
    start
    enable
  end
end
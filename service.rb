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
    server.run("systemctl start #{name}")
  end

  def restart
    server.run("systemctl restart #{name}")
  end

  def enable
    server.run("systemctl enable #{name}")
  end

  def start_and_enable
    start
    enable
  end
end
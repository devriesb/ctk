class Service
  attr_reader :name, :box

  def initialize(name, box)
    @name = name
    @box = box
  end

  def status
    box.cmd("systemctl status #{name}")
  end

  def stop
    box.cmd("systemctl stop #{name}")
  end

  def start
    res = box.cmd("systemctl start #{name}")

    if res.strip.length > 0
      puts "Error: \n"
      puts res.inspect
      raise "#{name} start failed on #{box.hostname}"
    end

    res
  end

  def restart
    res = box.cmd("systemctl restart #{name}")

    if res.strip.length > 0
      puts "Error: \n"
      puts res.inspect
      raise "#{name} restart failed on #{box.hostname}"
    end

    res
  end

  def enable
    box.cmd("systemctl enable #{name}")
  end

  def start_and_enable
    start
    enable
  end
end
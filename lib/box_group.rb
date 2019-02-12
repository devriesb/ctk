class BoxGroup < Array

  def puts_all
    self.each do |box|
      puts box.inspect
    end
  end


  def cmd_all(cmd, parallel: true)
    if parallel == true
      $running_in_parallel = true
      results = ::Parallel.map(self) do |box|
        puts "Running #{cmd} on #{box.hostname}"
        cmd_output = box.cmd(cmd)

        [box.hostname, cmd_output]
      end
      $running_in_parallel = false

      print_parallel_results(results)
    else
      self.each do |box|
        puts "Running #{cmd} on #{box.hostname}"
        puts box.cmd(cmd)
      end
    end
  end

  def each_in_parallel
    $running_in_parallel = true

    Parallel.each(self) do |box|
      output = yield box
      [box.hostname, output]
    end

    $running_in_parallel = false

    puts "Parallel operation complete, check 'log/<hostname>' for detailed results"
  end

  def print_parallel_results(results)
    results.each do |result|
      hostname = result[0]
      cmd_output = result[1]

      puts '-' * 30
      puts hostname
      puts '-' * 30
      puts
      puts cmd_output
      puts
    end
  end
end

class BoxGroup < Array

  def puts_all
    self.each do |box|
      puts box.inspect
    end
  end

  def each(parallel: true)
    
  end
end
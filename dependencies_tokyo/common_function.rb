module CommonFunction
  def complete?
    self.complete == 1
  end
  
  def complete!
    self.update_attributes({:complete => 1})
  end
end

class Array
  def blank?
    self.size.zero?
  end
end
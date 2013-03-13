class Task < TokyoRecord
  has_one :journal
  
  def complete!
    self.update_attributes({:complete => 1, :completed_at => Time.now})
  end
end
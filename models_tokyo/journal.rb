class Journal < TokyoRecord
   include CommonFunction
   
   # Relations
   has_many :volumes
   
   def has_toc?
     self.volumes.searchcount() != 0
   end
end
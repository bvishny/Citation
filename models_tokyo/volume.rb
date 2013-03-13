class Volume < TokyoRecord
   # Relations
   belongs_to :journal
   has_many :issues

end
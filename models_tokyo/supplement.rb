class Supplement < TokyoRecord
   include CommonFunction
   
   # Relations
   has_many :articles
end
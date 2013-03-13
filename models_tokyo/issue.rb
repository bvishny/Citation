class Issue < TokyoRecord
   include CommonFunction
   
   # Relations
   belongs_to :volume
   has_many :articles
end
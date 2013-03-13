class Article < TokyoRecord
    include CommonFunction # provides methods such as complete?
    
    # Relations
    belongs_to :issue

end
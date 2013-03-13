class Blackwell < Indexer
  attr_accessor :page # Denotes 
  attr_accessor :config
  attr_accessor :journal
  
  # Force reading of UTF-8
  $KCODE ='UTF8'
  
  # Put it all together!
  def index!
    go = true
    while go
      if page_state() == :complete
        markers = page_info()
        volume = Volume.init(markers[:volnum], self.journal, markers[:year])
        issue = Issue.init(markers[:issnum], volume, markers[:pages])
        if config[:bulk_insert]
          Article.bulk_insert_with_check(articles(issue.issue_id), 1, [:title, :issue_id]) # specify an issue_id in the articles() method if using bulk insert
        else
          articles().each { |article| Article.init(article[:title], issue, article) }
        end
        if done? 
          go = false
        else 
          self.page = prev_page()
        end
      end
    end
    self.journal.complete!
  end
  
  def done?
     self.page.links.select{|x| x.text =~ /Previous Issue/}.empty? 
  end
  
  def prev_page
    load(self.page.links.select{|x| x.text =~ /Previous Issue/}[0].attributes['href'])
  end
  
  # Page Analysis Methods
  def page_state
    if self.page.at("title").text.include? "Early View"
      :unpublished
    elsif self.page.search("//h4[@class='blackH4']").size == 0 and self.page.search("//strong").select { |strong| strong.text.include? "Volume" }.size == 0
      :empty
    else
      :complete
    end
  end
  
  def page_info
    # Define Regexp
    regexp_volume = /Volume [0-9A-Za-z]{1,4}/
    regexp_yr = /[0-9]{4,5}(?=\))/
    regexp_iss = /Issue [0-9A-Za-z]{1,4}/
    regexp_pgs = /Pages [0-9a-zA-Z]{1,5} - [0-9a-zA-Z]{1,5}/
    regexp_pg = /Page [0-9a-zA-Z]{1,5}/
    regexp_suppl = /suppl?. [0-9]{1,4}/
    
    locinfo = self.page.search("//h4[@class='blackH4']")
    locinfo = locinfo[0].text unless locinfo.empty?
    unless locinfo.to_s.include? "Volume"
      self.page.search("//strong").each { |s| 
        (locinfo = s.text; break) if s.text =~ regexp_volume
      }
    end
    yr = locinfo.match(regexp_yr)
    yr = (yr.nil?) ? 'No Year' :  yr[0]
    vol = locinfo.match(regexp_volume)[0].gsub("Volume ", "").gsub(" ", "")
    iss = (locinfo =~ regexp_iss and not locinfo.downcase.include? "suppl") ? locinfo.match(regexp_iss)[0].gsub("Issue ", "").gsub(" ", "") : ("S" + locinfo.downcase.match(regexp_suppl)[0].match(/[0-9]{1,4}/)[0])
    pgs = ((locinfo.match(regexp_pgs).nil?) ? ((locinfo.match(regexp_pg).nil?) ? "No Pages" : locinfo.match(regexp_pg)[0]) : locinfo.match(regexp_pgs)[0].gsub(" - ", "")).gsub("Pages", "").gsub("Page", "").gsub(" ", "")
    return {:year => yr, :volnum => vol, :issnum => iss, :pages => pgs}
  end
  
  def articles(issue_id=nil)
    listing = []
    regexp_pages = /\(p [0-9a-zA-Z]{1,4}-[0-9a-zA-Z]{1,4}\)/
    regexp_page = /p [0-9a-zA-Z]{1,5}/
    
    self.page.search("//p[@class='article-heading']").each { |article|
      for element in article.children
        case element.name
        when "strong"
          pages = ((element.text.match(regexp_pages).nil?) ? ((element.text.match(regexp_page).nil?) ? "No Pages" : element.text.match(regexp_page)[0].match(/[0-9a-zA-Z]{1,4}/)[0]) : element.text.match(/\(p [0-9a-zA-Z]{1,4}-[0-9a-zA-Z]{1,4}\)/)[0].to_s.match(/[0-9a-zA-Z]{1,4}-[0-9a-zA-Z]{1,4}/)[0])
          title = element.text.split("(p ")[0].gsub(/\302\240/, ' ').strip 
        when "text"
           ((element.text.include? "DOI:") ? (doi = element.text.split("DOI: ")[1]) : authors = element.text) if (element.text.length > 3 and not element.text.include? "Published Online")
        end
      end
       doi = "" unless doi
       if issue_id
         listing << {:title => title, :pages => pages, :doi => doi, :authors => authors, :uri => article.parent.children.css('a')[0].attributes['href'].to_s, :issue_id => issue_id, :instance => $controller.instance_id}
       else
         listing << {:title => title, :pages => pages, :doi => doi, :authors => authors, :uri => article.parent.children.css('a')[0].attributes['href'].to_s}
       end
    }
    listing
  end
end
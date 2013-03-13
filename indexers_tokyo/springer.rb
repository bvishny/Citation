class Springer < Indexer
  attr_accessor :page
  attr_accessor :config
  attr_accessor :journal
  
  # Put it all together!
  def index!
    go = true
    while go
      if page_state() == :complete
        markers = page_info()
        volume = Volume.init(markers[:volnum], self.journal, markers[:year])
        issue = Issue.init(markers[:issnum], volume, markers[:pages])
        if issue.new_issue
          Article.bulk_insert(articles(issue.id_issue)) # specify an id_issue in the articles() method if using bulk insert
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
     self.page.links.select{|x| x.text =~ /Prev vol\/iss/}.empty? 
  end
  
  def prev_page
    load(self.page.links.select{|x| x.text =~ /Prev vol\/iss/}[0].attributes['href'])
  end
  
  # Page Analysis Methods
  def page_state
    if self.page.search("//img[@src='/images/onlinefirst.gif']").size != 0
      :unpublished 
    elsif self.page.search("//div[@class='primitiveControl']").size < 2
      :empty
    else
      :complete
    end
  end
  
  def page_info
    # Define Regexp
    regexp_volume = /Volume [0-9A-Za-z]{1,4}/
    regexp_yr = /[0-9]{4,5}\)/
    regexp_iss = /Issue [0-9A-Za-z]{1,4}/
    regexp_pgs = /Pages [0-9a-zA-Z]{1,5}-[0-9a-zA-Z]{1,5}/
    regexp_pg = /Page [0-9a-zA-Z]{1,5}/
    regexp_suppl = /Supplement [0-9a-zA-Z]{1,4}/
    
    locinfo = self.page.at("title").text
    yr = locinfo.match(regexp_yr)
    yr = (yr.nil?) ? 'No Year' :  yr[0].gsub(")", "")
    vol = locinfo.match(regexp_volume)[0].gsub("Volume ", "").gsub(" ", "")
    iss = (locinfo =~ regexp_iss and not locinfo.downcase.include? "suppl") ? locinfo.match(regexp_iss)[0].gsub("Issue ", "").gsub(" ", "") : ("S" + locinfo.downcase.match(regexp_suppl)[0].match(/[0-9]{1,4}/)[0])
    pgs = ((locinfo.match(regexp_pgs).nil?) ? ((locinfo.match(regexp_pg).nil?) ? "No Pages" : locinfo.match(regexp_pg)[0]) : locinfo.match(regexp_pgs)[0].gsub("-", "")).gsub("Pages", "").gsub("Page", "").gsub(" ", "")
    return {:year => yr, :volnum => vol, :issnum => iss, :pages => pgs}
  end
  
  def articles(id_issue=nil)
    listing = []
    
    counter = -1
    self.page.search("//div[@class='primitiveControl']").select { |x| x.search("//div[@class='contentType']")[0].text.include? "Article" }.each { |article|
      pages = article.parent.parent.xpath('//td[@class="viewItem fontLarger"]')[counter].text.to_s.gsub("&nbsp;", "").gsub('\302\240', '').strip
      for element in article.parent.parent.children
        if a.attributes['class'].to_s.include? 'listItemName'
          title = a.text.to_s.gsub('\302\240', '').strip
          uri = a.attributes['href'].to_s
        elsif a.attributes['class'].to_s.include? 'listAuthors'
          authors = a.text.to_s.gsub(" and ", ", ").gsub('\302\240', '').strip
        end
      end
       doi = "" unless doi
       if id_issue
         listing << {:title => title, :pages => pages, :doi => doi, :authors => authors, :uri => uri, :id_issue => id_issue, :instance => $controller.instance_id}
       else
         listing << {:title => title, :pages => pages, :doi => doi, :authors => authors, :uri => uri}
       end
    }
    listing
  end
end
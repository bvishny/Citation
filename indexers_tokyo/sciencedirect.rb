class ScienceDirect < Indexer
  
  def initialize(journal, config = {:max_tries => 3, :uagent => "Mac Safari", :bulk_insert => true})
    unless $sd_last_login and $sd_last_login < (Time.now.to_i - 3600) # only login once every hour
      self.page = @agent.get('http://sciencedirect.com')
      2.times do |i|
        f = self.page.forms.first
        f.userid = 'userid'
        f.password = 'userid'
        self.page  = @agent.submit(f)
      end
      raise "LoginError" unless self.page.body =~ /User Name/
      $sd_last_login = Time.now.to_i
     end
     super
  end
  
  # Put it all together!
  def index!
    go = true
    while go
      if page_state() == :complete
        markers = page_info()
        (volume = Volume.init(markers[:volnum], self.journal, markers[:year]); parent = volume) if markers[:volnum]
        (issue = Issue.init(markers[:issnum], volume, markers[:pages]); parent = issue) if markers[:issnum]
        (supp = Supplement.init(markers[:suppnum], (issue ? issue : volume), markers[:pages]); parent = supp) if markers[:suppnum]
        if parent.created_at.to_i > (Time.now.to_i - 10) # if it was created in the last 10 seconds
          Article.bulk_insert(articles(parent.key)) # specify an id_issue in the articles() method if using bulk insert
        else
          articles().each { |article| Article.init(article['title'], parent, article) }
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
    self.page.links.select{|x| x.text =~ /Previous vol\/iss/}.empty? 
  end
  
  def prev_page
    load(self.page.links.select{|x| x.text =~ /Previous vol\/iss/}[0].attributes['href'].to_s)
  end
  
  # Page Analysis Methods
  def page_state
    (self.page.title.include? "Articles in Press") ? :unpublished : :complete
  end
  
  def page_info
    # Define Regexp
    regexp_volume = /Volum(e|es) ([0-9A-Za-z]{1,4}|[0-9A-Za-z]{1,4}-[0-9A-Za-z]{1,4})/
    regexp_yr = /([0-9]{4,4}|[0-9]{4,4}-[0-9]{4,4})(?=\))/
    regexp_iss = /Issu(e|es) ([0-9A-Za-z]{1,4}|[0-9A-Za-z]{1,4}-[0-9A-Za-z]{1,4})/
    regexp_pgs = /Pag(e|es) ([0-9a-zA-Z]{1,5}|[0-9a-zA-Z]{1,5}-[0-9a-zA-Z]{1,5})/
    regexp_suppl = /Supplement [0-9a-zA-Z]{1,4}/
    
    locinfo = self.page.title
    yr = locinfo.match(regexp_yr)
    yr = (yr.nil?) ? 'No Year' :  yr[0]
    vol = locinfo.match(regexp_volume)[0].gsub("Volume ", "").gsub("Volumes ", "").gsub(" ", "")
    pgs = (locinfo.match(regexp_pgs).nil?) ? "No Pages" : locinfo.match(regexp_pgs)[0].gsub("Pages", "").gsub("Page", "").gsub(" ", "")
    result = {:year => yr, :volnum => vol, :pages => pgs}
    begin
      result[:issnum] = locinfo.match(regexp_iss)[0].gsub("Issue ", "").gsub(" ", "") if locinfo =~ regexp_iss
      result[:suppnum] = locinfo.match(regexp_suppl)[0].gsub("Supplement ", "").gsub(" ", "") if locinfo.downcase.include? "supplement"
    rescue
      $controller.send_message "Encountered trouble parsing " + locinfo
    end
    result
  end
  
  def articles(id_parent=nil)
    listing = (id_parent) ? {} : []
    regexp_pages = /Pages [0-9a-zA-Z]{1,4}-[0-9a-zA-Z]{1,4}/
    regexp_page = /Page [0-9a-zA-Z]{1,5}/
    
    self.page.search("//td[@width='95%']//span[@style]").select { |x| not x.attributes['style'].to_s.include? "font-style: italic" }.each { |article|
      title, pages, authors = article.text, "No Pages", "No Author"
      for element in article.parent.parent.children
        case element.name
        when "i"
          pages = ((element.text.match(regexp_pages).nil?) ? ((element.text.match(regexp_page).nil?) ? "No Pages" : element.text.match(regexp_page)[0].match(/[0-9a-zA-Z]{1,4}/)[0]) : element.text.match(/[0-9a-zA-Z]{1,4}-[0-9a-zA-Z]{1,4}/)[0].to_s.match(/[0-9a-zA-Z]{1,4}-[0-9a-zA-Z]{1,4}/)[0])
        when "text"
          authors = element.text.strip if element.text =~ /[a-zA-Z]{2,5}/
        end
      end
       doi = "" unless doi
       if id_parent
         ts =  UUIDTools::UUID.timestamp_create.to_s
         listing[ts] = {:title => title, :pages => pages, :authors => authors, :uri => article.parent.attributes['href'].to_s, :id_parent => id_parent, :instance => $controller.instance_id}
       else
         listing << {:title => title, :pages => pages, :authors => authors, :uri => article.parent.attributes['href'].to_s, :instance => $controller.instance_id}
       end
    }
    listing
  end
end
class Indexer
  attr_accessor :page
  attr_accessor :config
  attr_accessor :journal
  
  # FORCE UTF-8 ENCODING
  $KCODE ='UTF8'
  
  # Initialize
  def initialize(journal, config = {:max_tries => 1, :uagent => "Mac Safari", :bulk_insert => true})
     @config, @journal = config, journal.update_attributes({:instance => $controller.set_source(self.class.to_s).instance_id})
     # Create Mechanize agent
     @agent = Mechanize.new { |a| 
        a.user_agent_alias = config[:uagent]
        a.history.max_size = 1
      }
      # Load Journal
      @page = load(journal.link)
  end

  # Loads a webpage (but not necessarily into the page attribute), retrying until success or max tries exceeded
  def load(uri, notify=true)
    (1..@config[:max_tries]).each { |tries|
      begin
        page = @agent.get(uri)
      rescue Exception => e
        $controller.report_exception(e, tries > @config[:max_tries]) if notify
      else
        break
      end
    }
    page
  end
end
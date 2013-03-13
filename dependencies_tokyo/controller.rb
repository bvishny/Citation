class Controller
	attr_accessor :current_source
	attr_accessor :worker_id
	attr_accessor :task
	
	def initialize
		self.worker_id = $worker.number
	end

	def set_source(class_name)
		abbrev = { "blackwell" => "BW", "sciencedirect" => "SD", "springer" => "SK"}
		@current_source = abbrev[class_name.downcase]
		self
	end
	
	def instance_id
	  (@current_source  ||= "IND") + "-" + @worker_id
	end
	
	def new_task
	  @task = Task.find(:first, :conditions => ["state = 'pending'"])
	  @task.update_attributes({:worker_id => $worker.key, :started_at => Time.now.to_i})self.task.id_worker = $worker.key
	  indexer = Object.const_get(@task.journal.provider.capitalize).new(@task.journal)
	  indexer.index!
	  @task.complete!
	end
	
	def report_exception(error, crash)
	   require 'net/http'
       message = "Indexer #{@instance_id} encountered an error #{(crash ? 'and must exit.' : 'but will not be required to exit.')}. The error is as follows: #{error} -> #{error.backtrace}"
       res = Net::HTTP.post_form(URI.parse('http://welch.econ.brown.edu/util/email_ben'),
                                   {'message'=> message})
	end
end
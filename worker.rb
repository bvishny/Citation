require 'rubygems'
require 'daemons'
Daemons.daemonize

begin
  Kernel.load 'require_all_tokyo.rb'

  $machine = Machine.find(ARGV[0])

  $worker = Worker.create({:machine_id => $machine.key})
  
  work = Worker.find(:first, :order => "number DESC")
  $worker.update_attributes({:number => (work.nil?) ? 1 : work.number.to_i + 1})

  $controller = Controller.new
  while $worker.command != "SHUTDOWN"
      $worker.update_attributes({:last_update = Time.now.to_i})
      $controller.new_task()
  end

  $worker.status = "INACTIVE"

rescue Exception => e
  require 'net/http'
   message = " The error is as follows: #{e} -> #{e.backtrace}"
   res = Net::HTTP.post_form(URI.parse('http://welch.econ.brown.edu/util/email_ben'),
                                 {'message'=> message})
  
end

exit
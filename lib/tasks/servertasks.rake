
#desc "halt web services"
#task :stop_server do
#  puts "Server would be halted here"
#end
#
#desc "start web services"
#task :start_server do
#  puts "Server would be started here"
#end
#
#desc "restart web services"
#task :restart_server do
#  puts "Server would be restarted here"
#end

namespace :delayed_job do
  desc "stop delayed jobs processes"
  task :stop => :environment do
    system("#{RAILS_ROOT}/script/delayed_job stop")
  end

  desc "start delayed jobs processes"
  task :start => :environment do
    system("#{RAILS_ROOT}/script/delayed_job -n 10 start")
  end

  desc "restart delayed jobs processes"
  task :restart do
    stop
    wait_for_process_to_end('delayed_job')
    start
  end
end

def wait_for_process_to_end(process_name)
  run "COUNT=1; until [ $COUNT -eq 0 ]; do COUNT=`ps -ef | grep -v 'ps -ef' | grep -v 'grep' | grep -i '#{process_name}'|wc -l` ; echo 'waiting for #{process_name} to end' ; sleep 2 ; done"
end




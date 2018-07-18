app_path = File.expand_path(File.dirname(__FILE__) + '/..')

working_directory app_path

if ENV["RAILS_ENV"] == "development"
  worker_processes 2
  listen 3000, backlog: 64
  #ENV["LOG_LEVEL"] =' debug'
else
  preload_app true
  worker_processes 9
  listen app_path + '/tmp/sockets/unicorn.sock', backlog: 64
  #ENV["LOG_LEVEL"] = 'warn' # 'debug'  'warn
  stderr_path app_path + '/log/unicorn.log'
  stdout_path app_path + '/log/unicorn.log'
end

pid app_path + '/tmp/pids/unicorn.pid'
timeout 60

GC.respond_to?(:copy_on_write_friendly=) &&
  GC.copy_on_write_friendly = true

before_fork do |server, worker|
  defined?(ActiveRecord::Base) &&
    ActiveRecord::Base.connection.disconnect!
end

after_fork do |server, worker|
  defined?(ActiveRecord::Base) &&
    ActiveRecord::Base.establish_connection
end

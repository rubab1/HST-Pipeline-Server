# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require(File.join(File.dirname(__FILE__), 'config', 'boot'))

require 'rake'
require 'rake/testtask'
require 'rdoc/task'

#require 'tasks/rails'
require File.expand_path('../config/application', __FILE__)
require 'rake'

Rpipeline::Application.load_tasks

task :ec2_update_status => :environment do
  STDERR.puts "ec2_update_status: begin ..."
  ActiveRecord::Base.logger.level = Logger::WARN
  Node.update_ec2_node_status
  STDERR.puts "ec2_update_status: end."
end

task :process_pipeline_queue => :environment do
  #STDERR.puts "process_pipeline_queue: begin ..."
  ActiveRecord::Base.logger.level = Logger::WARN
  #ActiveRecord::Base.logger.level = Logger::DEBUG
  process_name = "rake_task-process_pipeline_queue"
  owner_name = ENV['USER']  || "rake"
  pid = Process.pid
  #STDERR.puts "process_name : #{process_name.inspect} owner_name : #{owner_name.inspect} , pid : #{pid.inspect}"
  PipelineServer.process_pipeline_queue(process_name, owner_name, pid)
  STDERR.puts "."
  #STDERR.puts "process_pipeline_queue: end."
end

task :clear_pipeline_queue_locks => :environment do
  STDERR.puts "clear_pipeline_queue_locks: begin ..."
  ActiveRecord::Base.logger.level = Logger::WARN
  # ActiveRecord::Base.logger.level = Logger::DEBUG
  ServerLock.remove_locks_like("process_queue_")
  STDERR.puts "clear_pipeline_queue_locks: end."
end

task :do_node_housekeeping => :environment do
  STDERR.puts "do_node_housekeeping: begin ..."
  ActiveRecord::Base.logger.level = Logger::WARN
  #ActiveRecord::Base.logger.level = Logger::DEBUG
  Node.do_housekeeping
  STDERR.puts "do_node_housekeeping: end."
end

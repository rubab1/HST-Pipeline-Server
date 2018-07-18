
class Pipeline < ActiveRecord::Base
  belongs_to  :user
  belongs_to :server_node, :class_name => "ServerNode"
  has_many :targets, :dependent => :destroy
  has_many :tasks, :dependent => :destroy
  has_many :nodes, :dependent => :destroy
  has_one  :lock_log
  has_many :source_trees, :dependent => :destroy
  # attr_accessor :name, :software_root, :data_root, :configuration_root, :description, :pipe_root, :user_id, :user_key_file_name, :container_root
  include GuidHelper
  before_create :set_guid

  # TODO: add options flag to throw exception instead of just returning false
  # TODO: add options flag to call  poll ec2 state
  def all_nodes_ready(options = {} )
    result = false
    @pipeline_nodes = Node.where(pipeline_id: self.id)
    logger.info("pipline.all_nodes_ready : existing pipeline nodes = #{@pipeline_nodes.inspect}")
    return false if @pipeline_nodes.nil?
  
    state_name = (options[:state_name].nil?) ?  'ready' : options[:state_name]
    a_state = NodeState.find_by_name state_name
    raise "pipline.all_nodes_ready : can't find updating state id ?" if a_state.nil?
    # update each node
    @pipeline_nodes.each do |a_node|
      next if (a_node.name == 'localhost')
      result = (a_node.state_id == a_state.id)
    end
    logger.debug("pipline.all_nodes_ready : result = #{result.inspect}")
    return result
  end

  #
  # refresh
  # called when the software trees for this system need to be refreshed
  #
  def refresh
    @pipeline_nodes = Node.where(pipeline_id: self.id)
    logger.info("pipline.refresh : existing pipeline nodes = #{@pipeline_nodes.inspect}")
    raise "No Nodes found for pipeline id = #{self.id} " if @pipeline_nodes.nil?

    # update each node
    @pipeline_nodes.each do |a_node|
      next if (a_node.name == 'localhost')
      # make sure nodes are able to transition to the updating state
      ok = a_node.is_updateable
      if (! ok )
        logger.error("pipline.refresh  : pipeline #{self.id} , node not ready to update #{a_node.inspect}")
        next
      end
      a_node.enqueue_update 
    end
  end

  #
  # typically invoked by rake 
  # reviews jobs on the queue and asks if any can be submitted for work
  # on Nodes
  #
  def process_queue( parent_process_name, owner_name, pid=nil )
    begin
      # logger.info "process_queue: #{self.id} begin ..."
      # logger.info "process_queue: parent_process_name =#{parent_process_name.inspect} , owner_name=#{owner_name.inspect} "
      lock_name = "process_queue_#{self.id}"
      lock = nil
      begin
        lock = ServerLock.assert_lock_for(lock_name, owner_name, parent_process_name, pid)
      rescue Exception => e
	# puts "Getting lock error"
        logger.error "process_queue: #{self.id}  : could not get the lock ..."
        return false
      end
  
      state_ready = PipelineState.find_by_name 'ready'
      if self.state_id != state_ready.id
        # logger.info("pipeline not in ready state #{pipeline.state_id.inpect}, ignoring ...")
        return false
      end
  
      # select jobs awaiting launch
      jobs = Job.find_by_sql "SELECT jobs.* from jobs, tasks WHERE jobs.state='new' AND tasks.id = jobs.task_id AND tasks.pipeline_id=#{self.id}"
  
      if (jobs.empty?)

        return
      end
      logger.debug "jobs =  #{jobs.inspect}" 

  
      jobs.each do |j|
        logger.info "Pipeline #{self.id} : Considering job #{j.id}"
        # need to pick the "next" node to use ...
        # could use oder by num_jobs, and then use the lowest
        # could add last_job_id to node and use lowest
  
        # get happy node states ...
        # HACK HACK HACK
        #query_string = "SELECT * FROM `node_states` WHERE status = 1 AND name in ( 'ready', 'pipeline_task', 'updating' ) "
        query_string = "SELECT * FROM `node_states` WHERE status = 1 AND name in ( 'ready', 'pipeline_task' ) " 
        # logger.debug "Pipeline #{self.id} : node statue query = #{query_string}"
        node_states = NodeState.find_by_sql query_string
        if ( node_states.nil?) 
            #logger.debug 
			puts "Pipeline #{self.id} : can't find node_states ???"
            return
        end
        sss = Array.new()
        node_states.each do |n|
          sss.push(n.id.to_s)
        end
        happy_states = sss.join(',')
        # get nodes for this pipline that are "happy"
        query_string = "SELECT nodes.* from nodes WHERE nodes.pipeline_id = #{self.id} AND nodes.name != \"localhost\" AND nodes.state_id in ( #{happy_states} ) ORDER by nodes.last_job_id"
        # logger.debug "Pipeline #{self.id} : node query = #{query_string}"
        nodes = Node.find_by_sql query_string
        if ( nodes.nil?) 
            #logger.debug 
			puts "Pipeline #{self.id} : can't find nodes ???"
            return
        end
        nodes.each do |n|
           #logger.info 
			puts "Node #{n.name}, job #{j.id}"
          if (n.can_accept?(j.task))
            #logger.info 
			puts "Pipeline #{self.id} : Node #{n.inspect} consuming job #{j.inspect}"
            n.consume(j)
            break
          else
            # logger.debug "Node #{n.inspect} not able to consume , job #{j.inspect}"
            #logger.debug 
			puts "Pipeline #{self.id} : Node #{n.id} #{n.name.inspect} NOT able to consume , job #{j.inspect}"
          end
        end
      end
    ensure
      lock.destroy unless lock.nil?
    end
    # logger.info "process_queue: #{self.id} end."
  end

  def get_server_crypto_dirname
    dir = PipelineServer.get_crypto_dirname_for_pipeline self
    return dir
  end

  def ensure_crypto_dir
    PipelineServer.ensure_crypto_dir_for_user_id self.user_id
    dir = PipelineServer.ensure_crypto_dir_for_pipeline self
    return dir
  end

  def get_server_user_key_file
    file = PipelineServer.get_server_user_key_file_for_pipeline self
    return file
  end

  def get_root_key_filename
    file = PipelineServer.get_root_key_filename_for_user_id self.user_id
    return file
  end

  def get_root_key_filename!
    file = PipelineServer.get_root_key_filename_for_user_id! self.user_id
    return file
  end

  def get_node_base
        return "/sci/data01/node_pipelines/users/#{self.user_id}/pipelines/#{self.id}"
  end

  def get_node_pipe_root
    #HACK ... fix this - reflect node_type at very least  ...
    return "#{self.get_node_base}/#{self.pipe_root}"
  end

  def void_new_jobs
    # NOTE: can't use ? param, since this is using a deeper db access method, and there is no sql injection, since param comes only from self.id
    result = ActiveRecord::Base.connection.execute("UPDATE jobs jjj set jjj.state='void' where jjj.state='new'  AND jjj.task_id in (SELECT ttt.id FROM tasks ttt WHERE  ttt.pipeline_id = #{self.id})")
    return result
  end

  def Pipeline.get_shared_secret_by_id(pipeline_id)
    # logger.info("Pipeline.get_shared_secret_by_id id= #{pipeline_id.inspect}")
    pipeline = Pipeline.where(id: pipeline_id).first
    #logger.info("Pipeline.get_shared_secret_by_id pipeline #{pipeline.inspect}")
    raise "Unknown Pipeline" if pipeline.nil?
    return pipeline.shared_secret unless pipeline.shared_secret.nil?
    # else get from user
    user = User.where(id: pipeline.user_id).first
    # logger.info("Pipeline.get_shared_secret_by_id user #{user.inspect}")
    return user.guid 
  end

end

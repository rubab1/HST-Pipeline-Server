#=============================================================================================

require 'delayed_job'

class Node < ActiveRecord::Base
  belongs_to :pipeline
  belongs_to :user
  has_many :jobs
  has_many :options, :as => :optionable
  has_many :copy_states, :dependent => :destroy
  has_many :node_capabilities, :dependent => :destroy # eg: node has dolphot, idl, etc



  FREE_POOL_PIPELINE_ID = 0
  FREE_POOL_NODE_ID = 0

  SPOT_INSTANCE_PLACEHOLDER_ID = "i-spot"

  include Ec2Helper
  include SshHelper

  #===========================================================================================
  # TODO:  fix this to work with the node configuration files?
  #
  # returns the node's path to the program specified by the Task
  # currently hardwired until we decide what to do
  # eventually this path should be modified according to some parameter attached
  # to the node
  #
  def localPath(taskName)
    self.pipeline.pipe_root + "/build/prod/" + taskName
  end

  #===========================================================================================
  #
  # check status, requirements
  #
  def can_accept?(task)
    # logger.info(
    # puts "can_accept : task = #{task.inspect}, name = #{self.name}"
    return false if task.nil?
    return false if (self.name.eql?('localhost'))
    # status may change, so need to check
    # look at state and status 
    node_state = NodeState.where(id: self.state_id).first
    #TODO handle different node types ?
    can_run = false
    # puts "NODE state name = #{node_state.name}"
      case node_state.name
      # HACK HACK HACK
      when 'idle', 'ready', 'pipeline_task'
      # when 'idle', 'ready', 'pipeline_task', 'updating'
          can_run = true
    end
    if ( can_run ) 
      #  NOTE: you could look at node_type and get number of cpus and memory to calculate max num jobs ...
      #  12/6/2012 - temporarily limited the max number of jobs to 4 to control process
      # collisions.  
      if ((task.is_exclusive? && self.num_jobs > 1) || (self.num_jobs > 4) )
        can_run = false 
      end
    end
    # puts "Can_run? self.num_jobs=#{self.num_jobs} #{can_run}"
    if ( can_run ) 
      reqs = task.requirements
      # logger.warn("can_accept : requirements = #{reqs.inspect}")
      can_run = true 
      if ( !reqs.nil? )
        reqs.each do |req|
          # logger.warn("can_accept : req = #{req.inspect}")
          if (!req.node_meets(self))
            can_run = false 
            # logger.warn("can_accept : failed at req = #{req.inspect}")
	    # puts "can_accept : failed at req = #{req.inspect}"
            break
          end
        end
      end
    end
    # TODO: max num_jobs ?
    # TODO: look at load average
    # TODO: look at memory / swap etc
    # TODO: look at node and job "type" ? 
    # TODO: idl ?
    # logger.warn("can_accept : result = #{can_run.inspect}")
    return can_run
  end

  #===========================================================================================
  #
  # assigns a job to a node for processing
  #
  def consume(job)
    # logger.info "Node.consume start:  #{job.id}"
    # puts "Node.consume start: #{job.id}"
    job.node = self
    job.state = "starting"
    job.save

    # do this early so we don't give this node too many jobs ...
    self.last_job_id = job.id
    self.save!

    
	node_addr = self.get_prefered_network_address
	if node_addr == nil?
	  # puts "Inproperly configured node (#{self.id}, #{self.network_addr_ext}, #{self.network_addr_int}) - no prefered network address"
	end

    raise "Inproperly configured node (#{self.id}, #{self.network_addr_ext}, #{self.network_addr_int}) - no prefered network address" if node_addr.nil?
		

    # command = "ssh -i #{pipeline_server_key_file_for_node} puser@#{node_addr}  #{job.id} &"
    # logger.info "Node.consume:  #{command}"
    # result = Kernel.system(command)
    # puts "Node #{self.inspect} COnsume: #{job.inspect}"
    result = node_ssh_run_job(self, job)
    #logger.info 
    # puts "Node.consume RESULT:  #{result.inspect}"

    if (result[:exit_code] != 0)
      logger.info "Node.consume re-setting job.state to new ..."
      # failed command, so try again later
      job.state = "new"
      job.node_id = 0
      job.save
	  return 
    end

    self.num_jobs += 1
    self.save!
    
  end


  #===========================================================================================
  # since ec2 internal network traffic is free, prefer that, assuming we are talking cloud to cloud
  # Updated by Rubab: new EC2 security groups require VPCs, requiring use of external IP address
  # unless server and node resides on same VPC
  def get_prefered_network_address
    return self.network_addr_ext
    # return (self.network_addr_int.blank?) ? self.network_addr_ext : self.network_addr_int
    #return ( Rails.env == 'production' && !self.network_addr_int.blank?)  ? self.network_addr_int : self.network_addr_ext 
  end

  #===========================================================================================
  def update_node_state_for_user(user_id, new_state_id, options={})
    # logger.info(" update_node_state_for_user #{self.inspect} -> #{new_state_id} ")
    old_state_id = self.state_id
    self.state_id = new_state_id
    self.save!
    desc = options[:description]
    nodeStateTransition = NodeStateTransition.create() do |n|
      n.node_id = self.id
      n.user_id = user_id
      n.from_state = old_state_id
      n.to_state = new_state_id
      n.description = desc
    end
  end

  #===========================================================================================
  def is_updateable
    result = false
    return false if state_id.nil?
    node_state = NodeState.find(state_id)
    #TODO handle different node types ?
    return false if node_state.nil?
    case node_state.name
      when 'idle', 'running', 'ready', 'hold'
          result = true
    end
    if !desired_state_id.nil?
      desired_node_state = NodeState.find(desired_state_id)
      result = false
      case desired_node_state.name
        when 'idle', 'running', 'ready'
            result = true
      end
    end
    logger.info("Node is_updateable : #{node_state.name.inspect} -> #{result.inspect}")
    return result
  end

  #===========================================================================================
  # NOTE: this will take a long time - best called via delayed_job
  def do_update
    result = nil
    logger.info("Node: do_update start ... ")
    if (self.ec2_instance_id.nil?)
      logger.warn("Node: do_update unknown node type - ignoring")
    else
      result = ec2_node_run_cts self
    end
    logger.info("Node: do_update end result=#{result.inspect}")
    return result
  end

  #===========================================================================================
  def enqueue_update
    logger.debug("enqueue_update: begin ...")
    updating_state = NodeState.find_by_name 'updating'
    raise "node.enqueue_update : can't find updating state id ?" if updating_state.nil?
    logger.debug("enqueue_update: node before : #{self.inspect}")
    # set node_state to updating
    self.desired_state_id = updating_state.id
    self.save!
    # NOTE - that is a delayed_job enqueueing 
    self.delay.migrate_state
    logger.debug("enqueue_update: node now: #{self.inspect}")
    logger.debug("enqueue_update: end.")
  end

  #===========================================================================================
  # NOTE - this can be called by delayed_job ...
  def migrate_state
    logger.info("Node: migrate_state on #{self.inspect} ")
    node_state = NodeState.where(id: self.state_id).first
    if self.desired_state_id.nil?
          logger.info("Node: migrate_state : desired_state_id = nil ... ")
    else
      desired_node_state = NodeState.where(id: self.desired_state_id).first
      case desired_node_state.name
        when 'updating'
          logger.info("Node: migrate_state : starting update ...")
          updating_state = NodeState.find_by_name 'updating'
          self.desired_state_id = nil
          self.state_id = updating_state.id # TODO: should not have to do this, since update_node_sate_for_user does ...
          self.save! # TODO: should not have to do this, since update_node_sate_for_user does ...
          logger.debug("Node: update before #{self.inspect} ")
          self.update_node_state_for_user(self.user_id, updating_state.id, {:description => 'updating node' })
          logger.debug("Node: update after #{self.inspect} ")
          self.do_update
          logger.debug("Node: update done #{self.inspect} ")
          # when done, node pings notify, which should change node state ...
          logger.info("Node: migrate_state : done update.")
        else
          logger.info("Node: migrate_state : doing nothing for #{desired_node_state.inspect} ")
      end
    end
  end

  #===========================================================================================
  # http://www.mrchucho.net/2008/09/30/the-correct-way-to-override-activerecordbasedestroy
  def destroy_without_callbacks
    unless new_record?
      # if is ec2, try to move to pipeline free pool ...
      movedToFreePool = self.move_to_freepool
      if (movedToFreePool == true )
        logger.info("Node: destroy_without_callbacks : moving node #{self.id} to freepool ...")
        #TODO, if not using freepool, we need to call terminate ( async ? ) here
      else 
        logger.info("Node: destroy_without_callbacks : destroying node #{self.id} ...")
        self.delete
      end
    end
    freeze
  end

  #===========================================================================================
  def move_to_freepool
      result = false
      # if is ec2, try to move to pipeline free pool ...
      # TODO: kind of a hacky test ... feel free to make smarter ...
      if ((!self.ec2_instance_id.nil?) &&  ( self.state_id != 9 && self.state_id != 10 ) ) 
        logger.info("Node: move_to_freepool : moving node #{self.id} to freepool ...")
        self.pipeline_id = FREE_POOL_PIPELINE_ID;
        self.save
        result = true
      else 
        logger.info("Node: move_to_freepool : can't for node #{self.id} ...")
        result = false
      end
      return result
  end

  #===========================================================================================
  def self.get_nodes_from_freepool(pipeline, node_type, number_of_instances_to_launch  )
    result = nil
    user_id = pipeline.user_id
    # ready_state = NodeState.find_by_name("ready") # TODO:  do we need other states here ?
    # nodes = Node.find(:all, :limit => number_of_instances_to_launch, :conditions => { :pipeline_id => FREE_POOL_PIPELINE_ID, :state_id => ready_state.id, :type_id => node_type.id, :user_id => user_id })
    nodes = Node.where(pipeline_id: FREE_POOL_PIPELINE_ID, type_id: node_type.id, user_id: user_id).limit(number_of_instances_to_launch)
    # logger.info("get_nodes_from_freepool:  found nodes = #{nodes.inspect}")

    # #HACK for now ...
    # logger.info("get_nodes_from_freepool:  turned off until node update is working")
    # return nil

    if ! nodes.nil? 
      # update pipeline ID for 
      # TODO: make sure we got 
      nodes.each do |n|
        n.pipeline_id = pipeline.id
        n.save!
        logger.info("get_nodes_from_freepool: using free node #{n.inspect}")
      end
    end
    #TODO   finish this ...
    return nodes
  end

  #===========================================================================================
  def self.do_housekeeping()
    logger.info("node.do_house_keeping : begin ...  ")
    nodes = Node.all.order('user_id, pipeline_id')
    return false if nodes.nil?
    old_user = nil
    old_pipeline = nil
    ec2_status_for_user = nil
    description = "deleting node via do_house_keeping"
    terminated_state = NodeState.find_by_name('terminated')
    waiting_state = NodeState.find_by_name('waiting')
    # logger.info("node.do_house_keeping : terminated_state = #{terminated_state.inspect}")
    nodes.each do |a_node|
      logger.info("node.do_house_keeping : node = #{a_node.inspect}")
      delete_node = false
      # next if a_node.user_id.nil?
      if (a_node.name == 'localhost') 
        if ( a_node.pipeline.nil? )
          delete_node = true
          logger.info("node.do_house_keeping : localhost with no valid pipeline - deleting ")
        else
          if a_node.user_id.nil?
            logger.info("node.do_house_keeping : localhost fixing user_id ")
            a_node.user_id = a_node.pipeline.user_id
            a_node.save!
          end
        end
      end
      if (!a_node.ec2_instance_id.nil?)
        # if ( a_node.pipeline.nil? ) #NOTE: this presently cleans up "freepool nodes" since we are not using those at this time ...
        # if ( a_node.pipeline_id != FREE_POOL_PIPELINE_ID && a_node.pipeline.nil? )
        # logger.info("node.do_house_keeping :  no valid pipeline - deleting ")
        # delete_node = true
      # else
        # see if we need to refresh our cached status data ...
        old_user = a_node.user if old_user.nil?
        if ((!old_user.nil?) && (old_user.id != a_node.user_id ))
          logger.info("node.do_house_keeping : user = #{old_user.inspect}")
          # {"i-0a9e2960"=>"running"} 
          ec2_status_for_user = a_node.ec2_get_instances_status_for_user old_user.name
          logger.info("node.do_house_keeping : ec2 status for user = #{ec2_status_for_user.inspect}")
        end
        if ( ec2_status_for_user.nil? )
          if ( a_node.cost_model == "spot" )
            # TODO: waiting forever ?
            logger.info("node.do_house_keeping :  waiting for node #{a_node} ")
          else
            logger.info("node.do_house_keeping :  no ec2 status for node ")
            delete_node = true
          end
        else
          logger.info("node.do_house_keeping :  looking up ec2 status ")
          status = ec2_status_for_user[a_node.ec2_instance_id]
          if ( status.nil? || status == "terminated" )
            logger.info("node.do_house_keeping :  no valid ec2 status - deleting ")
            delete_node = true
          end
        end
      # end
    end 
    if (delete_node == true)
      logger.info("node.do_house_keeping : DELETING node = #{a_node.inspect}")
      a_node.update_node_state_for_user(a_node.user_id, terminated_state.id, {:description => description})
      a_node.delete
    end
  end
  logger.info("node.do_house_keeping : end.")
  return true
  end

  #===========================================================================================

  
  def self.ec2_post_configure_update(the_node)
    logger.debug("self.ec2_post_configure_update : begin .... #{the_node.inspect}")

    # get node info based on ec2_instance_id
    raise "Unable to update nil  node " if the_node.nil?

    the_ec2_instance_id = the_node.ec2_instance_id
    raise "Unable to update node with nill ec2_isntance_id" if the_ec2_instance_id.nil?

    the_pipeline = Pipeline.find_by_id the_node.pipeline_id
    logger.info("ec2_post_configure_update : #{the_ec2_instance_id} pipeline => #{the_pipeline.inspect}")
    raise "Unable to find pipeline for instance_id = #{the_ec2_instance_id} " if the_pipeline.nil?

    status_update_message = "updated by ec2_post_configure_update : #{the_ec2_instance_id}"

    #NOTE: this depends on the node having an IP addr, which means that we need to update status to get it
    instance_ids = []
    instance_ids.append(the_ec2_instance_id)
    reservations = the_node.ec2_get_instances_for_user(the_node.user_id, { :instance_ids => instance_ids})
    logger.debug("ec2_post_configure_update: ec2_status for #{the_ec2_instance_id } : #{reservations.inspect}")
    raise "Unable to get node status from EC2 for instance_id = #{the_ec2_instance_id} " if reservations.nil?
    reservations.each do |res|
      # loop over res instances
      # should only be 1 row, but need to loop on 
      res.instances.each do |inst|
        the_node.ec2_do_update_node_status inst, {:description => status_update_message }
      end
    end

    # IMPORTANT - reload node to get new status after update
    the_node = Node.where(ec2_instance_id: the_ec2_instance_id).first
    logger.info("ec2_post_configure_update : #{the_ec2_instance_id} node => #{the_node.inspect}")
    raise "Unable to find updated node for instance_id = #{the_ec2_instance_id} " if the_node.nil?

    # set node status to updating ...
    node_state_running = the_node.state_name_to_state 'running'
    node_state_updating = the_node.state_name_to_state 'updating'
    node_state_ready = the_node.state_name_to_state 'ready'

    # not calling ec2_post_configure_update as the last part of an update ?
    # if ((the_node.state_id != node_state_updating.id) && (!the_node.is_updateable))
      # logger.info("ec2_post_configure_update : #{the_ec2_instance_id} node NOT updatable!")
      # return
    # end

    logger.debug "updating node state to #{node_state_updating.inspect}"
    the_node.update_node_state_for_user(the_node.user_id, node_state_updating.id, {:description => status_update_message })

    begin

      # scp crypto key to node
      node_ip_addr = the_node.get_prefered_network_address
      ssh_login_key_file = the_pipeline.get_root_key_filename!
      ssh_key_file_to_install = the_pipeline.get_server_user_key_file
      node_pipe_root = the_pipeline.get_node_pipe_root
      the_node.node_ensure_pipeline_dir node_ip_addr, ssh_login_key_file, node_pipe_root
      the_node.node_install_ssh_key node_ip_addr, ssh_login_key_file, ssh_key_file_to_install, node_pipe_root
  
      the_node.base_path = the_pipeline.get_node_base
      the_node.save!

      logger.debug(" before cpipe init ...")
      # tell node pipeline to init - login as puser
      the_node.delay.node_ssh_cpipe_command(the_node, 'init')
      logger.debug(" after cpipe init ...")

      # set node status to ready ...
      logger.debug "updating node state to #{node_state_ready.inspect}"
      the_node.delay(run_at: 2.minutes.from_now).update_node_state_for_user(the_node.user_id, node_state_ready.id, {:description => status_update_message })
    rescue Exception => e
      logger.warn("ec2_post_configure_update:  Error : #{e.inspect}")
      status_update_message = "updated by ec2_post_configure_update : error, backing off : #{the_ec2_instance_id}"
      the_node.update_node_state_for_user(the_node.user_id, node_state_running.id, {:description => status_update_message })
      raise "ec2_post_configure_update:  Error : #{e.inspect}"
    end
    logger.debug "updating node done."
  end
  #===========================================================================================
end
#=============================================================================================
# EOF
#=============================================================================================

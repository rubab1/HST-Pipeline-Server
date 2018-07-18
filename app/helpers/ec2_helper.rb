# -*- coding: utf-8 -*-
# ====================================================================================
#
# ====================================================================================
# EC2 account ids - these are not secret - but handy to know for AMI sharing, etc
#
# dpirone   373487912678
# ben       417155379502
# karoline  374808267719
# keith     068224241016
# cliff     076977172131

# ====================================================================================
module Ec2Helper

  require 'rubygems'
	require 'aws-sdk'
  require 'json'
  require 'base64'

  RAILS_ENV= 'production'  # 'development'
  # EC2_CRYPTO_DATA = nil
  EC2_CRYPTO_DATA  = YAML.load_file("#{Rails.root}/config/ec2-crypto.yml")[RAILS_ENV]
  EC2_AMI_OWNER = 'ben'
  EC2_RESTRICTED_INSTANCES = [ 'i-0a9e2960', # pipeline1
    'i-225e0a4f', # cliff photometry server
    ]

  # ----------------------------------------------------------------------------------

  def ec2_node_run_cts( node )
    logger.debug("ec2_node_run_cts: being...")
    node_ip_addr = node.get_prefered_network_address
    ssh_login_key_file = node.pipeline.get_root_key_filename!
    logger.debug("ec2_node_run_cts: #{node_ip_addr} #{ssh_login_key_file}")
    result = node_run_cts node_ip_addr, ssh_login_key_file
    logger.debug("ec2_node_run_cts: result = #{result.inspect} ")
    logger.debug("ec2_node_run_cts: end.")
  end

  # ----------------------------------------------------------------------------------

  def ec2_root_key_file_base_name(user_id)
    #return 'uw_astro-key-001' 
    creds = ec2_get_crypto_assets_for_user(user_id)
    return creds['key_pair_name'];
  end

  def ec2_is_restricted_instance_id(ami_id)
    _inited
    return EC2_RESTRICTED_INSTANCES.include?(ami_id)
  end

  def ec2_get_users()
    _inited
    users = []
    EC2_CRYPTO_DATA.each_key do |u|
      users << u
    end
    return users
  end

  def ec2_get_crypto_assets_for_user(user)
    _inited
    user_name = _get_cred_name_from_user(user)
    creds = EC2_CRYPTO_DATA[user_name]
    raise "No assests for user #{user_name}" if creds.nil? rescue nil
    return creds
  end

  def ec2_get_instances_for_user(user_name, options={})
    _inited
    instances = nil
    creds = ec2_get_crypto_assets_for_user(user_name)
    ec2 = Aws::EC2::Client.new(:access_key_id => creds['access_key_id'], :secret_access_key => creds['secret_access_key'], :region => creds['region']) rescue nil
    #options[:owner_id] = creds['aws_user_id']
    res = ec2.describe_instances(options).reservations rescue nil
    #instances = res.item unless res.nil?
    # logger.debug "instances = #{instances.inspect}"
    #return instances
		return res
  end

  def ec2_get_amis()
    _inited
    amis = nil

    creds = ec2_get_crypto_assets_for_user(EC2_AMI_OWNER) # NOTE special var ....
    ec2 = Aws::EC2::Client.new(:access_key_id => creds['access_key_id'], :secret_access_key => creds['secret_access_key'], :region => creds['region'])
    #amis = ec2.describe_images(:owner_id => creds['aws_user_id']).images[0]
	amis = ec2.describe_images(:owners => ['amazon']).images
    #logger.debug "amis = #{amis.image_id} , #{amis.name}"
    return amis
  end

  def ec2_get_instances_status_for_user(user_name)
    _inited
    reservations = ec2_get_instances_for_user(user_name)
    return nil if reservations.nil?
    return ec2_get_status_from_instance_data(reservations)
  end

  def ec2_get_instance_status_for_user(user_name,instance_id)
    _inited
    reservations = ec2_get_instances_for_user(user_name,{:instance_id => instance_id})
    return nil if reservations.nil?
    status = {}
    # loop over reserverations, and then instances
    reservations.each do |res|
      res.instances.each do |iii|
            # logger.debug "\t III inst = #{iii.inspect}"
            return iii.instanceState.name
      end
    end

    return status
  end

  def is_server_node(inst)
   if inst.image_id == 'ami-df9452b2'
     return true
   else
     return false
   end
  end

  def ec2_launch_instances_for_server(user_name, ami_id, pipelines, options={})
    _inited
    creds = ec2_get_crypto_assets_for_user(user_name)
    ec2 = Aws::EC2::Client.new(:access_key_id => creds['access_key_id'], :secret_access_key => creds['secret_access_key'], :region => creds['region'])
    options[:image_id] = ami_id
    options[:min_count] = 1 
    options[:max_count] = 1
	options[:spot_price] = nil 

    options[:availability_zone] = nil # TODO - hardcoded
    options[:security_group_ids] = [creds['security_group_id']]
    options[:security_groups] = [creds['security_group_name']]
    options[:key_name ] = creds['key_pair_name']
    options[:instance_type ] = 'm4.xlarge'  if options[:instance_type ].blank?
    options[:block_device_mappings] = [ {:device_name => '/dev/sdb' , :virtual_name => 'ephemeral0'} , {:device_name => '/dev/sdc' , :virtual_name => 'ephemeral1'}]
    
    
    puts options.inspect
    result = ec2.run_instances(options)
	reservation_id  = result.reservation_id
    
    a_ec2_node = ServerNode.create() do |e|
       e.user_id = user_name
       e.type = InstanceType.where(name: options[:instance_type]).first 
       e.server_addr = result.instances[0].public_ip_address
       e.ec2_reservation_id = result.reservation_id
       e.ec2_root_key_name = result.instances[0].key_name
       e.ec2_instance_id = result.instances[0].instance_id
       #e.pipeline_start = pipeline_range[0]
       #e.pipeline_end = pipeline_range[1]
       e.status = 'running'
    end
    pipelines.each do |p|
      pid = p.gsub(' ', '')
      pipe = Pipeline.where(id: pid).first
      pipe.server_node = a_ec2_node
      pipe.save
    end
    a_ec2_node.save
    
    return result
  end

  # max_count = number to launch ...
  def ec2_launch_instances_for_user(user_name,ami_id, options={})
    _inited
    logger.debug("ec2_launch_instances_for_user: user_name=#{user_name}, ami_id=#{ami_id}, options=#{options.inspect}")
    creds = ec2_get_crypto_assets_for_user(user_name)
    ec2 = Aws::EC2::Client.new(:access_key_id => creds['access_key_id'], :secret_access_key => creds['secret_access_key'], :region => creds['region'])
    is_spot = ( options[:spot_price].blank? ) ? false : true;

    options[:image_id] = ami_id
    options[:availability_zone] = nil # TODO - hardcoded
    options[:security_group_ids] = [creds['security_group_id']]#["sg-fe487d87"]
    options[:security_groups] = [creds['security_group_name']]#["uw_astro-sg-001"]  # TODO - hardcoded
    options[:key_name ] = creds['key_pair_name']#ec2_root_key_file_base_name

    options[:user_data] = Base64.encode64(Node::FREE_POOL_PIPELINE_ID.to_i.to_json) if options[:user_data ].blank?

    options[:instance_type ] = 'm1.large'  if options[:instance_type ].blank?  # TODO - hardcoded

    # :block_device_mapping ([]) An array of Hashes representing the elements of the block device mapping.  e.g. [{:device_name => '/dev/sdh', :virtual_name => '', :ebs_snapshot_id => '', :ebs_volume_size => '', :ebs_delete_on_termination => ''},{},...]

    options[:block_device_mappings] = [ {:device_name => '/dev/sdb' , :virtual_name => 'ephemeral0'} , {:device_name => '/dev/sdc' , :virtual_name => 'ephemeral1'}]

    # :instance_initiated_shutdown_behavior (optional, String) — default: 'stop'  / 'terminate'

    if is_spot
      options[:instance_count] = options[:min_count]
    end

    logger.info("# # ec2_launch_instances_for_user: EC2 run options = #{options.inspect}")

    if is_spot
      options[:availability_zone_group] = 'us-east-1a'
			spot_options = Hash.new(options)
			spot_options = spot_options.except!(:instance_type)
			spot_options = spot_options.except!(:min_count)
			spot_options = spot_options.except!(:max_count)
			spot_options = spot_options.except!(:user_data)
			spot_options = spot_options.except!(:image_id)
			spot_options = spot_options.except!(:security_group_ids)
			spot_options = spot_options.except!(:security_groups)
			spot_options = spot_options.except!(:key_name)
			spot_options = spot_options.except!(:block_device_mappings)

			spot_options[:spot_price] = options[:spot_price]
			launch_spec = {}
			launch_spec[:instance_type] = options[:instance_type]
			launch_spec[:user_data] = options[:user_data]
			launch_spec[:image_id] = options[:image_id]
			launch_spec[:security_group_ids] = options[:security_group_ids]
			launch_spec[:security_groups] = options[:security_groups]
			launch_spec[:key_name] = options[:key_name]
			launch_spec[:block_device_mappings] = options[:block_device_mappings]

			spot_options[:launch_specification] = launch_spec
			logger.info("\n+++\nspot_options = #{spot_options.inspect}\n+++\n")

      res = ec2.request_spot_instances(spot_options)
			#res = ec2.run_instances({instance_type:"t1.micro", min_count:1, max_count:1})
    else
	  puts options.inspect
      res = ec2.run_instances(options)
			#ec2.instances.create(options)
    end
    logger.info("launch = #{res.inspect}")
    return res
  end

  def ec2_get_status_from_instance_data(reservations)
    _inited
    status = {}
    # loop over reserverations, and then instances
    reservations.each do |res|
      logger.debug "RRR res = #{res.reservation[0].reservation_id}"
      next if res.instances.nil?
      res.instances.each do |iii|
            # logger.debug "\t III inst = #{iii.inspect}"
            status[iii.instance_id]= iii.state.name
      end
    end
    return status
  end


  # called from rake - hence the puts over logger ...
  def ec2_update_node_status
    # @node_states usesd later ...
    @node_states = NodeState.where(status: 1)
    users = User.all
    return false if users.nil?
    users.each do |a_user|
      begin
        # puts "a_user : #{a_user.inspect}"
        reservations = ec2_get_instances_for_user a_user.name
        # puts "reservations : #{reservations.inspect}"
        next if reservations.nil?
        reservations.each do |res|
          res.instances.each do |inst|
            ec2_do_update_node_status inst
          end
        end
      rescue Exception => e
        puts "ec2_update_node_status: oops #{e.inspect}";
      end
    end
    return true
  end

  # ====================================================================================
  # creates model objects in addition to creating ec2 instances ...

  def ec2_launch_instances_for_pipeline(pipeline_id, user_id, node_type_id, number_of_instances=1 , options={})
    begin

      pipeline_id = pipeline_id.to_i
      if (pipeline_id != Node::FREE_POOL_PIPELINE_ID)
        pipeline = Pipeline.where(id: pipeline_id).first
        logger.debug("ec2_launch_instances_for_pipeline: pipeline = #{pipeline.inspect}")
        raise "Pipeline not found id = #{pipeline_id} " if pipeline.nil?
      end
      node_type = NodeType.where(id: node_type_id, status: 1).first
      raise "Invalid NodeType = #{node_type_id}" if node_type.nil?
      launch_state = NodeState.where(status: 1 , name: 'booting').first
      raise "Invalid NodeState = booting" if launch_state.nil?

      cost_model = (options[:cost_model].blank?) ? 'demand' : options[:cost_model]
      cost_base_price = options[:cost_base_price] # could be nil
      if ((cost_model != "demand") && (cost_base_price.blank?))
        raise "Missing cost_base_price for non demand node type"
      end
      is_spot = (cost_model == "spot" && !cost_base_price.blank?)

      options = {}
      options[:instance_type] = node_type.ec2_instance_type
      options[:min_count] = 1
      options[:max_count] = 1 # looping is done below now
      pid_string = (pipeline_id.is_a? String) ? pipeline_id : pipeline_id.inspect

      options[:user_data] = Base64.encode64(pipeline_id.to_json)

      options[:spot_price] = is_spot ?  cost_base_price : nil

      # loops over  num_instances
      result = []
      number_of_instances.times do
          ## create DB row to get node_id

          state_id = is_spot ?  NodeState.where(status: 1 , name: 'waiting').first.id : launch_state.id

          a_ec2_node = Node.create() do |e|
	    e.user_id = user_id
	    e.pipeline_id = pipeline_id
	    e.state_id = state_id
	    e.type_id = node_type.id
	    e.cost_model = cost_model
	    e.cost_base_price = cost_base_price
	  end
          a_ec2_node.save
          logger.info("ec2_launch_instances_for_pipeline: ec2_node => #{a_ec2_node.inspect}")

          ## create instance - passing in node_id
          logger.info("ec2_launch_instances_for_pipeline : options : #{options.inspect}")
          result = ec2_launch_instances_for_user(user_id, node_type.ec2_ami_id, options)
          logger.info("ec2_launch_instances_for_pipeline : launch result : #{result.inspect}")
          ## update row w/ instance data
	  if is_spot
	      instance_id = Node::SPOT_INSTANCE_PLACEHOLDER_ID
              reservation_id = result.spot_instance_requests[0].spot_instance_request_id
	      key_name = result.spot_instance_requests[0].launch_specification.key_name
              node_name = reservation_id
	  else
	      inst = result.instances.first
	      instance_id = inst.ec_instance_id 
              reservation_id  = result.reservation_id
	      key_name = inst.key_name
              node_name = inst.instance_id
	  end
	  a_ec2_node.update(
		ec2_reservation_id: reservation_id,
		ec2_root_key_name: key_name,
		ec2_instance_id: instance_id,
		name: node_name,
		)
      end

      return result # NOTE - this is now the status for the LAST node created - not all
    rescue Exception => e
      logger.info("ERROR: caught #{e.inspect}")
      raise e
    end
  end

  # ====================================================================================


  def ec2_do_update_node_status( ec2_api_instance_obj, options={} )
    return false if ec2_api_instance_obj.nil?
    begin
      @node_states = NodeState.where(status: 1) if @node_states.nil?

      description = ( options[:description].blank? ) ? 'updated by polling scanner' : options[:description]

      ec2_instance_id = ec2_api_instance_obj.instance_id
      present_instance_status = _clean_state_name ec2_api_instance_obj.state.name
      # puts "\tstatus #{ec2_instance_id} #{present_instance_status}"

      new_network_addr_ext = nil
      new_network_addr_int = nil
      # get obj for ec2_instance_id
      ec2node = Node.where(ec2_instance_id: ec2_instance_id).first
      # puts "ec2_do_update_node_status: node = #{ec2node.inspect}"
      return false if  ec2node.nil?
      # compare IP addrs - ext and int
      new_network_addr_ext = ec2_api_instance_obj.public_ip_address if ec2node.network_addr_ext  != ec2_api_instance_obj.public_ip_address
      new_network_addr_int = ec2_api_instance_obj.private_ip_address if ec2node.network_addr_int  != ec2_api_instance_obj.private_ip_address

      # compare states
      node_state = _state_id_to_state ec2node.state_id
      # puts "\t\t state:  was= #{node_state.name}  is= #{present_instance_status}"
      # update state if needed
      # here is magic ...
      update = false
      new_state = state_name_to_state present_instance_status
      raise "Unkown state #{present_instance_status} " if new_state.nil?
      case node_state.name
        when 'booting', 'registered'
         case new_state.name
          when 'running'
            update = true
         end
        else
          case new_state.name
            when 'shutting-down'
              puts "shutting down - fix me "
            when 'terminated'
              update = true unless node_state.name == 'terminated'
          else
            puts "falling through:  state:  was= #{node_state.name}  is= #{present_instance_status}"
          end
      end
      if (!new_network_addr_ext.nil?) or (!new_network_addr_int.nil?)
        # puts "updating network addrs : ext #{ec2node.network_addr_ext.inspect} -> #{new_network_addr_ext.inspect} int #{ec2node.network_addr_int.inspect} -> #{new_network_addr_int.inspect}"
        ec2node.network_addr_ext = new_network_addr_ext
        ec2node.network_addr_int = new_network_addr_int
        ec2node.save!
      end

      if update
        # record state transition as well as updating state
        # puts "updating state_id to #{new_state.id}"
        ec2node.update_node_state_for_user(ec2node.user_id, new_state.id, {:description => description})
      end
      return true

    rescue Exception => e
      puts "update_ec2_status: Error : #{e.inspect}"
      raise e
    end

  end

  # ====================================================================================
  def ec2_terminate_instances_for_pipeline( pipeline_id, options = {} )
    pipeline = Pipeline.where(id: pipeline_id).first
    logger.debug("ec2_terminate_instances_for_pipeline: pipeline = #{pipeline.inspect}")
    raise "Pipeline not found id = #{pipeline_id} " if pipeline.nil?
    user_id = pipeline.user_id
    # get instance ids that can be terminated
    # TODO: filter on node.state_id
    nodes = Node.where(pipeline_id: pipeline_id)
    raise "No ec2 nodes found for pipeline id = #{pipeline_id} " if pipeline.nil?
    ec2_instance_ids = []
    nodes.each do |node|
      ec2_instance_ids.append(node.ec2_instance_id) unless node.ec2_instance_id.nil?
    end

    ec2_instance_ids.each do |inst_id|
      server = ServerNode.find(:ec2_instance_id => inst_id).first
      if server
         server.pipelines.each do |p|
            p.server_node = nil
            p.save
         end
      end
    end

    logger.debug("ec2_terminate_instances_for_pipeline: ec2_instance_ids = #{ec2_instance_ids.inspect}")
    result = ec2_terminate_instances_for_user( user_id, ec2_instance_ids , options)
    return result
  end

  # ====================================================================================

  def ec2_terminate_instances_for_user( user_id, ec2_instance_ids, options = {} )
    creds = ec2_get_crypto_assets_for_user(user_id)
		ec2 = Aws::EC2::Client.new(:access_key_id => creds['access_key_id'], :secret_access_key => creds['secret_access_key'], :region => creds['region'])
    ids = Array.new 
    if (ec2_instance_ids.is_a? String )
      ids.push(ec2_instance_ids)
    elsif (ec2_instance_ids.is_a? Array )
      ids = ids + ec2_instance_ids
    end
    ids.each do |inst_id|
      server = ServerNode.where(ec2_instance_id: inst_id).first
      if server
         server.pipelines.each do |p|
            p.server_node = nil
            p.save
         end
      end
    end

    logger.debug("ec2_terminate_instances : ids = #{ids.inspect}")
    result = ec2.terminate_instances(:instance_ids=>ids)
    logger.debug("ec2_terminate_instances : result = #{result.inspect}")
    return result
  end

  # ====================================================================================

  def ec2_stop_instances_for_user( user_id, ec2_instance_ids, options = {} )
    creds = ec2_get_crypto_assets_for_user(user_id)
		ec2 = Aws::EC2::Client.new(:access_key_id => creds['access_key_id'], :secret_access_key => creds['secret_access_key'], :region => creds['region'])
    ids = Array.new
    if (ec2_instance_ids.is_a? String )
      ids.push(ec2_instance_ids)
    elsif (ec2_instance_ids.is_a? Array )
      ids = ids + ec2_instance_ids
    end
    logger.debug("ec2_stop_instances : ids = #{ids.inspect}")
    result = ec2.stop_instances(:instance_ids=>ids)
    logger.debug("ec2_stop_instances : result = #{result.inspect}")
    return result
  end

  # ====================================================================================

  def ec2_start_instances_for_user( user_id, ec2_instance_ids, options = {} )
    creds = ec2_get_crypto_assets_for_user(user_id)
		ec2 = Aws::EC2::Client.new(:access_key_id => creds['access_key_id'], :secret_access_key => creds['secret_access_key'], :region => creds['region'])
		ids = Array.new
    if (ec2_instance_ids.is_a? String )
      ids.push(ec2_instance_ids)
    elsif (ec2_instance_ids.is_a? Array )
      ids = ids + ec2_instance_ids
    end
    logger.debug("ec2_start_instances : ids = #{ids.inspect}")
    result = ec2.start_instances(:instance_ids=>ids)
    logger.debug("ec2_start_instances : result = #{result.inspect}")
    return result
  end

  # ====================================================================================

  def state_name_to_state( state_name)
    @node_states = NodeState.where(status: 1) if @node_states.nil?
    @node_states.each do |state|
      # puts "test : state_name = #{state.name} =? #{state_name}"
      return state if state.name == state_name
    end
    return nil
  end

  # ====================================================================================

  private
  def _inited()
    _load_data()  if EC2_CRYPTO_DATA.nil?
  end

  def _load_data()
    # get config from config file for now, but from memory
    # EC2_CRYPTO_DATA  = YAML.load_file("#{Rails.root}/config/ec2-crypto.yml")[RAILS_ENV]
    # puts "HERE: #{EC2_CRYPTO_DATA.inspect}"
    logger.debug("ec2_cryto_details updated ...")
  end

  def _clean_state_name( state_name)
    #HACK : magic mapping of ec2 'pending' into our 'booting'
    state_name = 'booting' if state_name == 'pending'
    return state_name
  end

  def _state_id_to_state( state_id)
    @node_states = NodeState.where(status: 1) if @node_states.nil?
    @node_states.each do |state|
      # puts "test : state_name = #{state.name} =? #{state.id}"
      return state if state.id == state_id
    end
    return nil
  end

  def _get_cred_name_from_user(user)
    #TODO deal with user object from DB
    user_name = user.to_s
    user_id = user.to_i
    if user_id > 0 # got a potential user_id int
      user_obj = User.where(id: user_id).first
      user_name = user_obj.name
    end
    return user_name
  end


end
# ====================================================================================
# EOF
# ====================================================================================

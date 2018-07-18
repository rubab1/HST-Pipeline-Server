# ==============================================================================

require 'delayed_job'
require 'json'
require 'base64'

class Ec2nodesController < ApplicationController


  include Ec2Helper
  include SshHelper


  layout 'ec2nodes'

  protect_from_forgery :except => :updater
  skip_before_action :verify_authenticity_token
  before_action :authenticate, :except => [ :get_status_api , :notify , :reparent_node ]


  def index
    redirect_to '/ec2nodes/get_users'
  end

  def get_users
    @header = 'EC2 users'
    @title = 'EC2 users'
    @users = User.all
    logger.debug("get_users : #{@users.inspect}")
  end

  # these are the AMIs EC2 knows about
  def get_registered_amis
    @header = 'EC2 Registered AMIs'
    @title = 'EC2 Registered AMIs'
    @amis = ec2_get_amis
    logger.debug("get_registered__amis : #{@amis.length}")
  end

  # these are our node types
  def get_amis
    @header = 'EC2 AMIs'
    @title = 'EC2 AMIs'
    #@amis = NodeType.get_active_ec2_node_types
    @amis = ec2_get_amis
    logger.debug("get_amis : #{@amis.inspect}")
    respond_to do |format|
      format.xml { render :xml => @amis.to_xml }
      format.json { render :json => @amis.to_json }
      format.html { }
    end
  end

  def get_status_for_user
    @user_id = params[:id]
    @user = User.where(id: @user_id).first
    # logger.debug("get_status_for_user: user = #{@user.inspect}")
    if @user.nil?
      raise "User not found id = #{@user_id} " rescue nil
    else
      @header = "EC2 user status for #{@user.name}"
      @title = "EC2 user status for #{@user.name}"
      @status = nil
      @free_pool_pipeline_id = Node::FREE_POOL_PIPELINE_ID
      @instance_pipeline_map = {}
      if ((!@authn_user.is_admin) && (@authn_user.id != @user.id ))
        logger.debug("get_status_for_user: unauth access for id #{@user_id.inspect} ...")
        flash[:error] = "Not authorized for id = #{@user_id} "
        redirect_to '/users'
      end
      @user_pipeline_ids = Pipeline.where(user_id:1).collect(&:id)
      begin
        @node_states = NodeState.where(status: 1)
        @status = ec2_get_instances_for_user(@user_id)
        @creds = ec2_get_crypto_assets_for_user(@user_id)
        # logger.debug("get_status_for_user: @status = #{@status.inspect}")
        if ! @status.nil?
          @status.each do |res|
            next if res.instances.nil?
                  #puts "RES: #{res.inspect}"
                  #next if res.instances[0].public_ip_address == "52.23.160.174"
            res.instances.each do |inst|
              #TODO - db query in a loop - not good
              an_ec2_node = Node.where(ec2_instance_id: inst.instance_id).first
              # logger.debug("get_status_for_user: registered ec2_node  = #{an_ec2_node.inspect}")
              @instance_pipeline_map[inst.instance_id] = (an_ec2_node.nil?) ? 'NA' : an_ec2_node
            end
          end
        end
    
        @mode = params[:mode] # for iframe view ...
    
        respond_to do |format|
          format.xml { render :xml => @status.to_xml }
          format.html { }
        end
    
      # rescue Exception => e
        # respond_to do |format|
          # flash[:error] = "Error : #{e.inspect}"
          # format.html { }
          # format.xml { render :xml => @status.errors.to_xml, :status => 500 }
        # end
      end  
    end
  end

  #TODO: authZ
  def launch_instances_for_user
    @user_id = params[:id]
    @header = "EC2 launch instances for user.id #{@user_id}"
    @title = "EC2 launch instances for user.id #{@user_id}"
    #@node_types = NodeType.get_active_ec2_node_types
    @all_node_types = NodeType.all
    @node_amis = Array.new
    @node_instance_types = Array.new
    @all_node_types.each do |node|
      if @node_amis.include?node.ec2_ami_id.inspect
      elsif node.ec2_ami_id
        @node_amis.push(node.ec2_ami_id.inspect)
      end
      if @node_instance_types.include?node.ec2_instance_type.inspect
      elsif node.ec2_instance_type
        @node_instance_types.push(node.ec2_instance_type.inspect)
      end	   
    end
    @pipeline_ids_for_user = Pipeline.where(user_id: @user_id)
    #logger.debug("launch_instances_for_user: node_types = #{@node_types.length} #{@node_types.inspect}")
  end

  #TODO: authZ
  #TODO: refactor this code to use shared code in helper
  def do_launch_instances_for_user
    # redirect_to :action => "index" and return unless request.post?
    @status = nil
    begin
      @user_id = params[:id]  # TODO: validate user
      @number_of_instances = (params[:number_of_instances].blank?) ? 1 : params[:number_of_instances].to_i
      @node_types = NodeType.get_active_ec2_node_types

      logger.debug("node types: #{@node_types.inspect}")
      @node_type_id = nil
      @node_types.each do |node|
        if node.ec2_ami_id.inspect == params[:node_ami] and node.ec2_instance_type.inspect == params[:node_instance_type]
          @node_type_id = node.id
        end
      end
      if @node_type_id == nil
        raise Exception.new("Node type (ami=#{params[:node_ami]}, instance_type=#{params[:node_instance_type]}) is not an active node type")
      end
      #@node_type_id = params[:node_type_id]
      @price_model = params[:price_model]
      @spot_price = params[:spot_price]
      @pipeline_id = params[:pipeline_id]

      options = {}
      options[:cost_model] = @price_model
      if (@price_model == "spot")
        options[:cost_base_price] = @spot_price
      end
      logger.info("do_launch_instances_for_user : options = #{options.inspect}")
      @status = ec2_launch_instances_for_pipeline(@pipeline_id, @user_id, @node_type_id, @number_of_instances, options)

      flash[:notice] = "Request ID : #{@price_model=="spot"?@status.spot_instance_requests[0].spot_instance_request_id : @status.reservation_id}"
      redirect_to :action => 'get_status_for_user', :id => @user_id

    rescue Exception => e
      logger.warn("do_launch_instances_for_user Error : #{e.inspect}")
      flash[:error] = "Error : #{e.inspect}"
      redirect_to :action => 'get_status_for_user', :id => @user_id
    end
  end

  def notify
    @cmd = params[:cmd]
    @ec2_reservation_id = params[:ec2_reservation_id]
    @ec2_instance_id = params[:ec2_instance_id]
    @ec2_user_data = params[:ec2_user_data]
    # get node info based on ec2_instance_id
    @node = Node.where(ec2_instance_id: @ec2_instance_id).first
    logger.info("notify : #{@ec2_instance_id} node => #{@node.inspect} : user_data => #{@ec2_user_data}")
    is_spot = false
    if @node.nil?
        # get node info based on ec2_reservation_id ( spot instances )
        #pipeline_id = Base64.decode64(@ec2_user_data)
	pipeline_id = @ec2_user_data.to_i
        # DJP: might be wrong user if pipeline_id = freepool
        @nodes = Node.where(pipeline_id: pipeline_id, ec2_instance_id: Node::SPOT_INSTANCE_PLACEHOLDER_ID)
        
        logger.info("notify : spot:  nodes = #{@nodes.inspect}")
        if @nodes.nil?
             @status = 'error-unknown_pipeline_id-and-spot_instance'
            logger.warn("nofify Error : #{@status}")
            render :layout => false, :status => 500
            return
        end
        @node = @nodes[0] # use first one
        is_spot = true
    end

    if @node.nil?
      @status = 'error-unknown_id'
      logger.warn("nofify Error : #{@status}")
      render :layout => false, :status => 500
      return
    end

    if is_spot
        # fill in instance_id etc
        @node.ec2_instance_id = @ec2_instance_id
        if @node.pipeline_id.nil?
            @node.pipeline_id = Node::FREE_POOL_PIPELINE_ID
        end
        @node.save
        # force fresh load
        @node = Node.where(ec2_instance_id: @ec2_instance_id).first
    end

    if  @node.pipeline_id !=  Node::FREE_POOL_PIPELINE_ID
      @pipeline = Pipeline.find_by_id @node.pipeline_id
      logger.info("notify : #{@ec2_instance_id} pipeline => #{@pipeline.inspect}")
      if @pipeline.nil?
        @status = 'error-bad_node_pipeline'
        logger.warn("nofify Error : #{@status}")
        render :layout => false, :status => 500
        return
      end
    end

#TODO:  branch on @cmd  if we get more values than 'post-cts'
    # HACK HACK HACK
    Node.ec2_post_configure_update @node
    # Node.delay.ec2_post_configure_update @node

    render :layout => false, :text => 'ok'
  end


  #TODO: authZ
  def do_terminate_instances_for_user
    user_id = params[:id]  # TODO: validate user
    ec2_instance_id = params[:ec2_instance_id]  # TODO: validate user
    begin
      # protect infra instances
      raise "Unable to terminate restricted instance: #{ec2_instance_id}" if ec2_is_restricted_instance_id ec2_instance_id
      @status = ec2_terminate_instances_for_user( user_id, ec2_instance_id)
      node = Node.where(ec2_instance_id: ec2_instance_id).first
      if (!node.nil?)
        logger.warn("do_terminate_instances_for_user: delete db node #{node.inspect}")
        node.delete # NOTE: delete - NOT destroy
      end
      respond_to do |format|
        format.xml { render :xml => @status.to_xml }
        format.json { render :json => @status.to_json }
        format.html {
          flash[:info] = "Note : #{@status.inspect}"
          redirect_to :action => 'get_status_for_user', :id => user_id
        }
      end
    rescue Exception => e
      logger.warn("do_terminate_instances_for_user Error : #{e.inspect}")
      flash[:error] = "Error : #{e.inspect}"
      redirect_to :action => 'get_status_for_user', :id => user_id
    end
  end

  #TODO: authZ
  def do_stop_instances_for_user
    user_id = params[:id]  # TODO: validate user
    ec2_instance_id = params[:ec2_instance_id]  # TODO: validate user
    begin
      # protect infra instances
      raise "Unable to stop restricted instance: #{ec2_instance_id}" if ec2_is_restricted_instance_id ec2_instance_id
      @status = ec2_stop_instances_for_user( user_id, ec2_instance_id)
      node = Node.where(ec2_instance_id: ec2_instance_id).first
      if (!node.nil?)
        # TODO update node.state ... ?
      end
      respond_to do |format|
        format.xml { render :xml => @status.to_xml }
        format.json { render :json => @status.to_json }
        format.html {
          flash[:info] = "Note : #{@status.inspect}"
          redirect_to :action => 'get_status_for_user', :id => user_id
        }
      end
    rescue Exception => e
      logger.warn("do_stop_instances_for_user Error : #{e.inspect}")
      flash[:error] = "Error : #{e.inspect}"
      redirect_to :action => 'get_status_for_user', :id => user_id
    end
  end

  #TODO: authZ
  def do_start_instances_for_user
    user_id = params[:id]  # TODO: validate user
    ec2_instance_id = params[:ec2_instance_id]  # TODO: validate user
    begin
      # protect infra instances
      raise "Unable to start restricted instance: #{ec2_instance_id}" if ec2_is_restricted_instance_id ec2_instance_id
      @status = ec2_start_instances_for_user( user_id, ec2_instance_id)
      node = Node.where(ec2_instance_id: ec2_instance_id).first
      if (!node.nil?)
        # TODO update node.state ... ?
      end
      respond_to do |format|
        format.xml { render :xml => @status.to_xml }
        format.json { render :json => @status.to_json }
        format.html {
          flash[:info] = "Note : #{@status.inspect}"
          redirect_to :action => 'get_status_for_user', :id => user_id
        }
      end
    rescue Exception => e
      logger.warn("do_start_instances_for_user Error : #{e.inspect}")
      flash[:error] = "Error : #{e.inspect}"
      redirect_to :action => 'get_status_for_user', :id => user_id
    end
  end

  def get_status_api
    @user_name = params[:username]
    @status = nil
    @instance_pipeline_map = {}
    @results = {}
    begin
      @users = []
      if (@user_name == 'all')
        @users = User.all.order('name');
      else
        @users =  User.where(name: @user_name).first
        logger.debug("get_status_for_user: user = #{@users.inspect}")
        raise "User not found name = #{@user_name} " if @users.nil?
      end

      @node_states = NodeState.where(status: 1)

      @users.each do |user|
        logger.debug("status for user: #{user.name}")
        @status = nil
        begin
          @status = ec2_get_instances_for_user(user.id)
        rescue Exception => e
          logger.debug("problem getting status for user #{user.name} : #{e.inspect}")
          next
        end

        # logger.debug("get_status_for_user: @status = #{@status.inspect}")
        if ! @status.nil?
          @status.each do |res|
            next if res.instancesSet.nil?
            res.instancesSet.item.each do |inst|
              #TODO - db query in a loop - not good
              an_ec2_node = Node.where(ec2_instance_id: inst.instance_id).first
              # logger.debug("get_status_for_user: registered ec2_node  = #{an_ec2_node.inspect}")
              @instance_pipeline_map[inst.instance_id] = (an_ec2_node.nil?) ? 'NA' : an_ec2_node
            end
          end
        end
        @results[user.name] = @status
      end

      respond_to do |format|
        format.xml { render :xml => @results.to_xml }
        format.json { render :json => @results.to_json }
        format.html { render :text => @results.inspect }
      end

    rescue Exception => e
      logger.debug("oops: #{e.inspect}")
      respond_to do |format|
        format.xml { render :xml => @e.to_xml, :status => 500 }
        format.json { render :json => @e.to_json, :status => 500 }
        format.html { render :text => @e.inspect, :status => 500 }
      end
     end
  end


  # TODO: authZ
  def reparent_node

    @user_id = params[:id]

    # example ec2 json data for spot :  {"imageId"=>"ami-f160a698", "privateIpAddress"=>"10.122.186.91", "instanceType"=>"t1.micro", "productCodes"=>nil, "keyName"=>"uw_astro-key-001", "privateDnsName"=>"ip-10-122-186-91.ec2.internal", "launchTime"=>"2012-06-30T22:47:42.000Z", "clientToken"=>"3a2f837f-185e-4b71-90d9-9b1aec24c903", "amiLaunchIndex"=>"0", "spotInstanceRequestId"=>"sir-ce72be12", "rootDeviceType"=>"ebs", "reason"=>nil, "ramdiskId"=>"ari-b31cf9da", "virtualizationType"=>"paravirtual", "instanceLifecycle"=>"spot", "instanceId"=>"i-f83bd180", "rootDeviceName"=>"/dev/sda1", "architecture"=>"x86_64", "ipAddress"=>"184.73.22.209", "monitoring"=>{"state"=>"disabled"}, "kernelId"=>"aki-b51cf9dc", "placement"=>{"availabilityZone"=>"us-east-1d", "groupName"=>nil}, "dnsName"=>"ec2-184-73-22-209.compute-1.amazonaws.com", "instanceState"=>{"code"=>"16", "name"=>"running"}, "blockDeviceMapping"=>{"item"=>[{"ebs"=>{"attachTime"=>"2012-06-30T22:48:23.000Z", "status"=>"attached", "volumeId"=>"vol-1cc5207d", "deleteOnTermination"=>"true"}, "deviceName"=>"/dev/sda1"}]}}

    # inspect of it <Node id: 107, name: "54dfa802-c756-4d59-ad33-58461143b92b", region: nil, agent: nil, pipeline_id: 0, created_at: "2012-06-14 04:48:45", updated_at: "2012-06-14 04:48:45", status: nil, base_path: nil, user_id: 1, type_id: 20, ec2_reservation_id: "54dfa802-c756-4d59-ad33-58461143b92b", ec2_instance_id: "54dfa802-c756-4d59-ad33-58461143b92b", ec2_root_key_name: "uw_astro-key-001", state_id: 12, desired_state_id: nil, network_addr_ext: nil, network_addr_int: nil, num_jobs: 0, last_job_id: nil, cost_model: "spot", cost_base_price: "0.11">

    @node = nil
    # find node by node id
    @node_id = params[:node_id]
    @node = Node.find_by_id @node_id
    logger.info("reparent_node : node_id #{@node_id} node => #{@node.inspect}")

    # find node by instance id
    if @node.nil?
      @ec2_instance_id = params[:ec2_instance_id]
      # get node info based on ec2_instance_id
      @node = Node.where(ec2_instance_id: @ec2_instance_id).first
      logger.info("reparent_node : #{@ec2_instance_id} node => #{@node.inspect}")
    end

    # find node by reservation id
    if @node.nil?
      @ec2_reservation_id = params[:ec2_reservation_id]
      @node = Node.where(ec2_reservation_id: @ec2_reservation_id).first
      logger.info("reparent_node : ec2_reservation_id #{@ec2_reservation_id} node => #{@node.inspect}")
      # deal with cost_model
    end

    if @node.nil?
      @status = "Can't find a node by any of the passed params"
      logger.warn("reparent_node Error : #{@status}")
      flash[:error] = @status
      redirect_to :action => 'get_status_for_user', :id => @user_id
      return
    end

    if ( ec2_is_restricted_instance_id(@node.ec2_instance_id) )
      @status = "ERROR: CAN NOT CHANGE INFRASTRUCTURE Nodes"
      logger.warn("reparent_node Error : #{@status}")
      flash[:error] = @status
      redirect_to :action => 'get_status_for_user', :id => @user_id
      return
    end

    # TODO: is @node currently doing work ?

    # TODO: check that user owns new pipeline
    @new_pipeline_id = params[:new_pipeline_id].to_i
    @new_pipeline = nil
    if (@new_pipeline_id  == Node::FREE_POOL_PIPELINE_ID )
      logger.info("reparent_node : DEPARENTING node_id #{@node.id} ")
      @node.move_to_freepool
    else
      @new_pipeline = Pipeline.find_by_id @new_pipeline_id
      logger.info("reparent_node : node_id #{@node.id} new_pipeline => #{@new_pipeline.inspect}")
      if (@new_pipeline.nil? )
        @status = "New Pipeline #{@new_pipeline.id} does NOT exist"
        logger.warn("reparent_node Error : #{@status}")
        flash[:error] = @status
        redirect_to :action => 'get_status_for_user', :id => @user_id
        return
      end

      # does it have an existing pipeline ?
      @pipeline = Pipeline.find_by_id @node.pipeline_id
      logger.info("reparent_node : node_id #{@node.id} pipeline => #{@pipeline.inspect}")
      if (@pipeline.nil? || @pipeline.id == 0)
        # deal with freepool ?
      else
        # TODO:  actually reparent ..., until then ...
        @status = "Node Is already in a Pipeline #{@pipeline.id}"
        logger.warn("reparent_node Error : #{@status}")
        flash[:error] = @status
        redirect_to :action => 'get_status_for_user', :id => @user_id
        return
      end

      # update node data
      @node.pipeline_id = @new_pipeline_id
       @node.save!
      # force fresh load
      @node = Node.find_by_id @node_id
      logger.info("reparent_node : after save node_id #{@node_id} node => #{@node.inspect}")

      if ( @node.get_prefered_network_address.nil? )
        # node was never fully inited via CTS notify ... finish up now ...
        # HACK HACK HACK
        Node.ec2_post_configure_update @node
        # Node.delay.ec2_post_configure_update @node
      else
        # enqueue update to set/reset pipeline data ...
        @node.enqueue_update
      end
    end

    @status = "Ok - reparenting for node #{@node.id} done."
    flash[:notice] = @status
    redirect_to :action => 'get_status_for_user', :id => @user_id
  end


end
# ==============================================================================
# EOF
# ==============================================================================

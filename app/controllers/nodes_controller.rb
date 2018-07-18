class NodesController < ApplicationController

  include Ec2Helper

  before_action :authenticate

  layout 'main'

  def new
    format.xml do
    
    end
  end

  def refresh
    @node = Node.find(params[:id])
    logger.debug("node.refresh node=#{@node.inspect}")
    if (@node.pipeline_id == 0)
      flash[:notice] = "Not able to refresh freepool node ( node.pipeline_id = 0 )"
    else
      @node.enqueue_update
      flash[:notice] = "Node refresh enqueued ..."
    end
    respond_to do |format|
      format.xml { render :xml => @node.to_xml(:include => {:jobs =>{:only =>[:id]},:options =>{:only =>[:id]}}) }
      format.html { 
        redirect_to :action => 'show', :id => @node.id
      }
    end
    rescue  Exception => e
      respond_to do |format|
        format.html { 
          flash[:error] = "Error with Node refresh #{e.inspect}"
          redirect_to :action => 'show', :id => @node.id
        }
        format.xml { render :xml => @node.errors.to_xml, :status => 500 }
      end
  end

  def show
    @node = Node.find(params[:id])
    @pipeline = @node.pipeline

    respond_to do |format|
      format.xml { render :xml => @node.to_xml(:include => {:jobs =>{:only =>[:id]},:options =>{:only =>[:id]}}) }
      format.html { }
    end

  rescue ActiveRecord::RecordInvalid

    respond_to do |format|
      format.html { redirect_to nodes_path }
      format.xml { render :xml => @node.errors.to_xml, :status => 500 }
    end
  end


  def instance
    @node = Node.where(ec2_instance_id: params[:id]).first

    respond_to do |format|
      format.xml { render :xml => @node.to_xml(:include => {:jobs =>{:only =>[:id]},:options =>{:only =>[:id]}}) }
      format.html { }
    end

  rescue ActiveRecord::RecordInvalid

    respond_to do |format|
      format.html { redirect_to nodes_path }
      format.xml { render :xml => @node.errors.to_xml, :status => 500 }
    end
  end


  def byname
    @node = Node.find_by_name(params[:id])

    respond_to do |format|
      format.xml { render :xml => @node.to_xml(:include => {:jobs =>{:only =>[:id]},:options =>{:only =>[:id]}}) }
      format.html { }
    end

  rescue ActiveRecord::RecordInvalid

    respond_to do |format|
      format.html { redirect_to nodes_path }
      format.xml { render :xml => @node.errors.to_xml, :status => 500 }
    end
  end

  def index

   @nodes = nil
    if @authn_user.is_admin
      @nodes = Node.all.order('user_id, pipeline_id, created_at ASC')
    else
      @nodes = Node.where(user_id: @authn_user.id).order('pipeline_id, created_at ASC')
    end
    # logger.debug("nodes=#{@nodes.inspect}")
    states = NodeState.where(status: 1)
    @node_states = []
    states.each do |state|
      @node_states[state.id] = state.name
    end
    logger.debug("node_states=#{@node_states.inspect}")
    types = NodeType.where(status:1)
    @node_types = []
    types.each do |type|
      @node_types[type.id] = type.name
    end
    logger.debug("node_types=#{@node_types.inspect}")
    respond_to do |format|
      format.xml { render :xml => @nodes.to_xml }
      format.html { }
    end
  
  end

  def get
    @task = Pipeline.find(params[:pipeline_id])
    @node = @pipeline.nodes.build
    @types = NodeType.all
    logger.debug("nodes:get node=#{@node.inspect}")
  end


  def edit
  end

  def newcloud
      @pipeline   = Pipeline.find(params[:id])
      @user       = @pipeline.user
      @nodes      = NodeType.all
      @node_type  = ""
      @node_count = 0
      @node_options = ""
  end

  def create
    @pipeline   = Pipeline.find(params[:pipeline_id])
    @user       = @pipeline.user
    #@node       = @pipeline.nodes.build(params[:node])
	@node = Node.create() do |n|
		n.name = params[:node][:name]
		n.region = params[:node][:region]
		n.agent = params[:node][:agent]
		n.status = params[:node][:status]
		n.base_path = params[:node][:base_path]
		n.pipeline_id = params[:pipeline_id]
	end	
    @node.user_id = @user.id if @node.user.nil? #make sure even localhost nodes have users set
    @node_type  = NodeType.get_by_name "localhost"
    @node.save!
    logger.debug("nodes:create node= #{@node.inspect}")

    respond_to do |format|
      format.xml  { render :xml => @node.to_xml, :status => :created }
      format.html { redirect_to pipeline_nodes_path(@pipeline) }
    end

    rescue ActiveRecord::RecordInvalid
    respond_to do |format|
      format.html { render :action => 'new' }
      format.xml  { render :xml => @node.errors.to_xml, :status => 500 }
    end
  end

  #
  # requests that a new collection of nodes get created
  #
  def invoke
      @pipeline_id = params[:pipeline_id]
      @pipeline = Pipeline.find(@pipeline_id)
      logger.debug("pipeline.invoke: pipeline = #{@pipeline.inspect}")
      raise "Pipeline not found id = #{@pipeline_id} " if @pipeline.nil?
  
      @number_of_instances = (params[:node_count].blank?) ? 1 : params[:node_count].to_i
      raise "Invalid number_of_instances #{@number_of_instances}" if @number_of_instances < 0
      @requested_node_type  = params[:node_type]
      @requested_options    = params[:node_options]
      @requested_includes   = params[:node_includes]
      @requested_pricing    = params[:node_pricing]  # supports bids for spot instances
  
      # validate type
      node_type = NodeType.get_by_name @requested_node_type
      # NOTE: remember keith add the solonode type to db via migration :)
      raise "Invalid Node Type" if node_type.nil?
  
      # see if they are already started ...
      @pipeline_nodes = Node.where(pipeline_id: @pipeline_id, type_id: node_type.id)
      logger.debug("pipeline.invoke: existing pipeline nodes = #{@pipeline_nodes.inspect}")
      num_usable_nodes = 0
      # check quantity
      # check state
      if ! @pipeline_nodes.nil?
          @pipeline_nodes.each do |a_node|
            #TODO move this to a method in Node ?
            logger.debug("pipeline.invoke: inspecting existing nodes = #{a_node.inspect}")
            # TODO:  move to node state by name - these ids can shift ...
            case a_node.state_id 
              when 1..8
                num_usable_nodes += 1
              when 9,10 
                logger.debug("pipeline.invoke: node was shutting_down / teminated")
              else
                logger.error("pipeline.invoke: unknow node_state  = #{a_node.inspect}")
            end
          end
        end
        @status = {}
        @number_of_instances_to_launch = @number_of_instances - num_usable_nodes
        if @number_of_instances_to_launch < 0
          logger.warn("pipeline.invoke: there are more nodes than needed for pipeline #{@pipeline_id} - wanted #{@number_of_instances} - found #{num_usable_nodes}")
          #TODO - reap unneeded nodes ( adding to freepool ... )
        end
   
        if @number_of_instances_to_launch == 0
          logger.info("pipeline.invoke: pipeline #{@pipeline_id} already has  #{@number_of_instances} nodes ")
          @status = {}
          @status[:status] = 'ok'
          @status[:message] = "already have  #{@number_of_instances} nodes"
        end
   
        if @number_of_instances_to_launch > 0
          logger.info("pipeline.invoke: pipeline #{@pipeline_id} - wanted #{@number_of_instances} - found #{num_usable_nodes} - invoking #{@number_of_instances_to_launch}")
  
          num_free_nodes = 0
          free_nodes  = Node.get_nodes_from_freepool(@pipeline, node_type, @number_of_instances_to_launch  )

          if !free_nodes.nil?
            num_free_nodes = free_nodes.size
            @number_of_instances_to_launch = @number_of_instances_to_launch - num_free_nodes
            logger.debug("pipeline.invoke: got #{num_free_nodes} from freepool ...")
            # call refresh on nodes gotten from freepool
            free_nodes.each do |fn|
              # logger.debug("pipeline.invoke: enqueuing refresh/update on freepool node #{fn.inspect} ...")
              fn.enqueue_update
            end
          end

          options= {}
          options[:cost_base_price] = nil
          if (!@requested_pricing.blank? ) 
            options[:cost_mode] = "spot"
            options[:cost_base_price] = @requested_pricing
            logger.debug("pipeline.invoke:  spot options => #{options}")
          end

          if @number_of_instances_to_launch > 0
            logger.debug("pipeline.invoke:  need #{@number_of_instances_to_launch} more nodes of type #{node_type.inspect}")
            # switch on type
            if node_type.is_standalone_node
              # TODO:  ....
              raise "keith - lets figure this out"
            elsif node_type.is_ec2_node
             new_node_info =  ec2_launch_instances_for_pipeline(@pipeline_id, @pipeline.user_id, node_type.id, @number_of_instances_to_launch,options)
            else
              logger.info "No actions for  Node Type #{node_type.inspect}"
              raise "Invalid Node Type" 
            end
          end
        end
        #TODO: turn @status into proper response code ...
        @status = {}
        @status[:status] = 'ok'
        @status[:free_nodes_info] = free_nodes
        @status[:new_nodes_info] = new_node_info
        logger.debug("pipeline.invoke: status = #{@status.inspect}")

   
        respond_to do |format|
          format.xml { render :xml => @status.to_xml , :status => :created }
          format.json { render :json => @status.to_json , :status => :created }
          format.html { 
            flash[:notice] = "Reservation ID : #{reservation_id}"
            redirect_to :action => 'get_status_for_user', :id => @pipeline.user_id
            # redirect_to pipeline_targets_path(@pipeline) 
          }
        end
    rescue Exception => e
      respond_to do |format|
        format.html { 
            flash[:error] = "Error : #{e.inspect}"
            redirect_to :action => 'get_status_for_user', :id => @pipeline.user_id
        }
        format.xml  { render :xml => @target.errors.to_xml, :status => 500 }
      end
  end

  def destroy
    @node = Node.find(params[:id])
    logger.debug("node.destroy node=#{@node.inspect}")
    @node.delete
    respond_to do |format|
      format.html { 
        flash[:notice] = "Node destroy #{@node.inspect} ..."
        redirect_to :action => 'index'
      }
    end
    rescue  Exception => e
      respond_to do |format|
        format.html { 
          flash[:error] = "Error with Node destroy #{e.inspect}"
          redirect_to :action => 'show', :id => @node.id
        }
        format.xml { render :xml => @node.errors.to_xml, :status => 500 }
      end
  end

  def _form
  end

end

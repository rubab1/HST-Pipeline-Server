class ServerNodesController < ApplicationController
  include Ec2Helper
  include SshHelper

  before_action :authenticate, :except => [ :get_status_api , :notify , :reparent_node ]
  #skip_before_action :verify_authenticity_token
  protect_from_forgery :except => :updater
  # GET /server_nodes
  # GET /server_nodes.json
  def index
    #@server_nodes = ServerNode.all, :order => 'created_at DESC'
    

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @server_nodes }
    end
  end

  # GET /server_nodes/1
  # GET /server_nodes/1.json
  def show
    #@server_nodes = ServerNode.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @server_node }
    end
  end

  # GET /server_nodes/new
  # GET /server_nodes/new.json
  def new
    @server_node = ServerNode.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @server_node }
    end
  end

  # GET /server_nodes/1/edit
  def edit
    @server_node = ServerNode.find(params[:id])
  end

  def launch_server
    @user_id = params[:id]
    @user = User.where(id: @user_id).first
    # @user = User.find(:first, :conditions => {:id => @user_id})
    @node_amis = ["ami-df9452b2"]
    @header = "EC2 launch server instances of for user.id #{@user.name}"
    @title = "EC2 launch server instances for user.id #{@user_id}"
    @node_instance_types = InstanceType.all 
    #TODO: Hard coded now
  end

  def do_launch_instances_for_server
    @user_id = params[:id]
    @node_ami = params["node_ami"]
    options = {}
	#@pipeline_range = []
    #@pipeline_range.push(params[:pipeline_start].to_i)
    #@pipeline_range.push(params[:pipeline_end].to_i)
    @pipelines = params[:pipelines].split(",")
    options[:instance_type] = InstanceType.where(id: params[:node_instance_type].to_i).first.name
    @pipelines.each do |p|
      pid = p.gsub(' ', '')
      pipe = Pipeline.where(id: pid).first
      if pipe == nil
         render :json => { :error => "pipeline #{p} doesn't exist",
          :status => 400 }
         return 
      elsif pipe.server_node
         render :json => { :error => "pipeline #{p} has been taken by other servers",
          :status => 400 }
         return 
      end
    end

    @status = ec2_launch_instances_for_server(@user_id, @node_ami, @pipelines, options)
    redirect_to :action => 'get_status_for_server', :id => @user_id
  end

  def get_status_for_server
    @user_id = params[:id]
    @user = User.where(id: @user_id).first
    # @user = User.find(:first, :conditions => {:id => @user_id})
    # logger.debug("get_status_for_user: user = #{@user.inspect}")
    raise "User not found id = #{@user_id} " if @user.nil?
    @header = "Server nodes status for #{@user.name}"
    @title = "Server nodes status for #{@user.name}"
    @status = nil
    @instance_pipeline_map = {}
    @user_pipeline_ids = Pipeline.where(user_id:1).collect(&:id)
    begin
      @node_states = NodeState.where(status: 1)
      # @node_states = NodeState.find(:all, :conditions => {:status => 1})
      @status = ec2_get_instances_for_user(@user_id)
      @creds = ec2_get_crypto_assets_for_user(@user_id)
      # logger.debug("get_status_for_user: @status = #{@status.inspect}")
      if ! @status.nil?
        @status.each do |res|
          next if res.instances.nil?
          res.instances.each do |inst|
            #TODO - db query in a loop - not good
            logger.debug("inst id = #{inst.instance_id}")
            an_ec2_node = ServerNode.where(ec2_instance_id: inst.instance_id).first
            if an_ec2_node 
				logger.debug("get_status_for_user: registered ec2_node  = #{an_ec2_node.inspect}")
			end
            @instance_pipeline_map[inst.instance_id] = an_ec2_node
            logger.debug("pass instance_pipeline_map")
          end
        end
      end

      @mode = params[:mode] # for iframe view ...

      respond_to do |format|
        format.xml { render :xml => @status.to_xml }
        format.html { }
      end
    end
  end

  # POST /server_nodes
  # POST /server_nodes.json
  def create
    #@server_node = ServerNode.new(params[:server_node])
    #@server_node = ServerNode.create() do |n|
    #  n.name = params[:node][:name]
	#  n.region = params[:node][:region]
	#  n.status = params[:node][:status]

    #end

    respond_to do |format|
      if @server_node.save
        format.html { redirect_to @server_node, notice: 'Server node was successfully created.' }
        format.json { render json: @server_node, status: :created, location: @server_node }
      else
        format.html { render action: "new" }
        format.json { render json: @server_node.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /server_nodes/1
  # PUT /server_nodes/1.json
  def update
    @server_node = ServerNode.find(params[:id])

    respond_to do |format|
      if @server_node.update_attributes(params[:server_node])
        format.html { redirect_to @server_node, notice: 'Server node was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @server_node.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /server_nodes/1
  # DELETE /server_nodes/1.json
  def destroy
    @server_node = ServerNode.find(params[:id])
    @server_node.destroy

    respond_to do |format|
      format.html { redirect_to server_nodes_url }
      format.json { head :no_content }
    end
  end
end

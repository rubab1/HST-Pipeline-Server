class TargetsController < ApplicationController

  before_action :authenticate
  layout "main"

  def show
    @target = Target.find(params[:id])
    @pipeline = @target.pipeline
    respond_to do |format|
      format.xml { render :xml => @target.to_xml }
      format.html { }
    end

  rescue ActiveRecord::RecordInvalid

    respond_to do |format|
      format.html { redirect_to pipeline_path }
      format.xml { render :xml => @target.errors.to_xml, :status => 500 }
    end
  end

  def index
    if (params[:pipeline_id])
      @pipeline = Pipeline.find(params[:pipeline_id])
      @targets    = @pipeline.targets
    else
      @targets    = Targets.all
    end

    respond_to do |format|
      format.xml { render :xml => @targets.to_xml }
      format.html { }
    end
  end

  def get
    @pipeline = Pipeline.find(params[:pipeline_id])
    @target = @pipeline.targets.build
  end

  def create
	#"target"=>{"name"=>"Unsorted", "relativepath"=>"Unsorted", "pipeline_id"=>"1044"}
    @pipeline = Pipeline.find(params[:pipeline_id])
    @target = @pipeline.targets.build(params[:target])
    @target.save!

    # Every new target gets a default configuration.
    # The default Default configuration has nothing in it, so if a client
    # wants something more, it should upload a Default based on a local
    # file with appropriate contents
    #
    configuration = @target.configurations.build(:name => "default",
      :relativepath =>"conf/default.conf");
    configuration.save!


    respond_to do |format|
      format.xml  { render :xml => @target.to_xml, :status => :created }
      format.html { redirect_to pipeline_targets_path(@pipeline) }
    end

    rescue ActiveRecord::RecordInvalid
    respond_to do |format|
      format.html { render :action => 'new' }
      format.xml  { render :xml => @target.errors.to_xml, :status => 500 }
    end
  end

  def edit
    @pipeline = Pipeline.find(params[:pipeline_id])
    @target   = Target.find(params[:id])
  end

  def destroy
    @pipeline = Pipeline.find(params[:pipeline_id])
    @target   = Target.find(params[:id])
    @target.destroy
    
    respond_to do |format|
      format.html { redirect_to pipeline_targets_path(@pipeline) }
      format.xml { head :ok }
    end
  end

  def update
    @pipeline = Pipeline.find(params[:pipeline_id])
    @target     = Target.find(params[:id])
    @target.attributes = params[:target]
    @target.save!

    respond_to do |format|
      format.html { redirect_to pipeline_target_path(@pipeline, @target) }
      format.xml { render :xml => @target.to_xml, :status => :ok }
    end

    rescue ActiveRecord::RecordInvalid

    respond_to do |format|
      format.html { render :action => 'edit' }
      format.xml { render :xml => @target.errors.to_xml, :status => 500 }
    end
  end

  def newjob
    @target    = Target.find(params[:id])
    @pipeline  = @target.pipeline 
    @tasks     = @pipeline.tasks
    @configurations = @target.configurations
  end

  # using the StartTask, create a start event for the desired job, and
  # fire it off.
  def startjob
    @target    = Target.find(params[:id])
    @pipeline  = @target.pipeline
    @configuration = ::Configuration.find(params[:configuration][:id])
    @task          = Task.find(params[:task][:id])

    # all "start" events begin with the startTask, which fires a start event
    # which actually creates the real job

    @starttask     = Task.where(pipeline_id: @pipeline.id, name: "StartTask").first

    # need test to ensure existence of StartTask

    @startjob      = Job.create_from_task_and_config @starttask, @configuration
    @event         = @startjob.events.build(:name=>'start', :value=>@task.name, :jargs => params[:job][:args])
    @event.save
    @startjob.state = "completed"
    @startjob.save
    @event.fire

    redirect_to target_path(@target.id)
  end

  def findorcreateconfiguration
    @target        = Target.find(params[:id])
    @configuration = ::Configuration.where(target_id: @target.id, name: params[:name]).first

    if (@configuration.nil?)
      relpath = "data/#{@target.name}/conf_#{params[:name]}/#{params[:name]}.conf"
      @configuration =  @target.configurations.build(:name=>params[:name], :relativepath =>relpath);
      @configuration.save! unless @configuration.nil?
    end

    unless @configuration.nil?
      respond_to do |format|
        format.xml { render :xml => @configuration.to_xml(:include=>{:parameters=>{:only =>[:id]},:data_products =>{:only =>[:id]}}) }
        format.html { @configuration }
      end
    else
      respond_to do |format|
        format.xml { render :xml => "No such record", :status => :ok }
        format.html { redirect_to target_path }
      end
    end
    @configuration
  end

  #
  # used to copy a configuration from one target to another
  # pass this the id of a configuration from some other target
  # and we copy it into this one - overwriting a configuration of the
  # same name if it exits
  #
  def cloneconfiguration
    @target        = Target.find(params[:id])
    @externalconf  = ::Configuration.find(params[:configuration_id])
    @configuration = ::Configuration.where(target_id: @target.id, name: @externalconf.name).first;

    if (@configuration.nil?)
      relpath = "data/#{@target.name}/conf_#{@externalconf.name}/#{@externalconf.name}.conf"
      @configuration = @target.configurations.build(:name=>@externalconf.name, :relativepath =>relpath, :description=>@externalconf.description);
      @configuration.save! unless @configuration.nil?
    end

    @configuration.copy_parameters(@externalconf)
    respond_to do |format|
      format.xml { render :xml => @configuration.to_xml(:include=>{:parameters=>{:only =>[:id]},:data_products =>{:only =>[:id]}}) }
      format.html { @configuration }
    end
  end
  
end

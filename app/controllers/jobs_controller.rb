class JobsController < ApplicationController

  before_action :authenticate
 
  layout 'main'
 
  def index
    @jobs = nil
    if (params[:task_id].nil?)
      @jobs = Job.all.order('created_at ASC')
    else
      @task = Task.find(params[:task_id])
      @jobs    = @task.jobs
    end
    respond_to do |format|
      format.xml { render :xml => @jobs.to_xml }
      format.html { }
    end
  end

  def by_task
    @task = Task.find(params[:task_id])
    @jobs    = @task.jobs
    respond_to do |format|
      format.xml { render :xml => @jobs.to_xml }
      format.html { }
    end
  end

  def show
    @job               = Job.find(params[:id])
    @task              = @job.task
    @configuration     = @job.configuration
    @target            = @configuration.Target  # all the good names are taken!
    @node              = @job.node

    # logger.debug("job.show: job=#{@job.inspect}")
    # logger.debug("job.show: task=#{@task.inspect}")

    if (@job.nil?)
      respond_to do |format|
        format.xml { render :xml => "No such record", :status => 500 }
        format.html { redirect_to '/' }
      end
    #elsif (@task.pipeline_id != params[:pipeline_id])#Integer(params[:pipeline_id]))
    elsif params[:pipeline_id] == nil
      respond_to do |format|
        format.xml { render :xml => @job.to_xml(:include => {:options =>{:only =>[:id]}}) }
        format.html { }
      end
      
    elsif (@task.pipeline_id != Integer(params[:pipeline_id]))

      logger.debug("Job rejection:\n");
      logger.debug("task=#{@task.inspect}")
      logger.debug("job=#{@job.inspect}")

      respond_to do |format|
        format.xml { render :xml => "Job not found in pipeline.  Job (#{@job.id}, from pipeline #{@task.pipeline_id} ), this pipeline (#{params[:pipeline_id]})", :status => 500 }
        format.html { redirect_to '/' }
      end
    else
      respond_to do |format|
        format.xml { render :xml => @job.to_xml(:include => {:options =>{:only =>[:id]}}) }
        format.html { }
      end
    end

    rescue ActiveRecord::RecordInvalid

    respond_to do |format|
      format.html { redirect_to task_path }
      format.xml { render :xml => @job.errors.to_xml, :status => 500 }
    end
  end

  def get
    @task = Task.find(params[:task_id])
    @job = @task.jobs.build
  end

  def new
    @task = Task.find(params[:task_id])
    @job = @task.jobs.build
    @targets = Target.all
    @configurations = ::Configuration.all
  end


  def create
    @task = Task.find(params[:task_id])
    @job = @task.jobs.build(params[:job])
    @job.save!

    respond_to do |format|
      format.xml  { render :xml => @job.to_xml(:include => {:options =>{:only =>[:id]}}), :status => :created }
      format.html { redirect_to task_jobs_path(@task) }
    end

    rescue ActiveRecord::RecordInvalid
    respond_to do |format|
      format.html { render :action => 'new' }
      format.xml  { render :xml => @job.errors.to_xml, :status => 500 }
    end
  end

  def edit
    @job  = Job.find(params[:id])
    @nodes = @job.task.pipeline.nodes
  end

  def destroy
    @task = Task.find(params[:task_id])
    @job  = Job.find(params[:id])
    @job.destroy
    
    respond_to do |format|
      format.html { redirect_to task_jobs_path(@task) }
      format.xml { head :ok }
    end

  end

  # The only things that can change are the state and node assignment
  def update
    @job  = Job.find(params[:id])
    @job.state = params[:job][:state] unless params[:job][:state].nil?
    @job.node_id = params[:job][:node_id] unless params[:job][:node_id].nil?
    # TODO - keith  finish this up
    if @job.state == "completed" || @job.state == "failed"
      @job.mark_as_done
    end
    @job.save!

    respond_to do |format|
      format.html { redirect_to job_path(@job) }
      format.xml { render :xml => @job.to_xml(:include => {:options =>{:only =>[:id]}}), :status => :ok }
    end

    rescue ActiveRecord::RecordInvalid

    respond_to do |format|
      format.html { render :action => 'edit' }
      format.xml { render :xml => @job.errors.to_xml, :status => 500 }
    end
  end

  # ...well, the configuration might get updated too
  def updateconfiguration
    @job  = Job.find(params[:id])
    @job.configuration_id = params[:cid] unless params[:cid].nil?
    @job.save!

    respond_to do |format|
      format.html { redirect_to job_path(@job) }
      format.xml { render :xml => @job.to_xml(:include => {:options =>{:only =>[:id]}}), :status => :ok }
    end

    rescue ActiveRecord::RecordInvalid

    respond_to do |format|
      format.html { render :action => 'edit' }
      format.xml { render :xml => @job.errors.to_xml, :status => 500 }
    end
  end

  def setoption
    # @job = Job.find(params[id])
    @option = Option.where(optionable_id: params[:id], optionable_type: "Job", name: params[:name]).first
    if (@option.nil?)
      @job = Job.find(params[:id])
      @option = @job.options.build
      @option.name = params[:name]
    end
    @option.value = params[:value]
    @option.save!

    respond_to do |format|
      format.html { redirect_to option_path(@option) }
      format.xml  { render :xml => @option.to_xml, :status => :ok }
    end

  end


  def getoptions
    @options = Option.where(optionable_id: params[:id], optionable_type: "Job")

    respond_to do |format|
      format.html { }
      format.xml  { render :xml => @options.to_xml, :status => :ok }
    end
  end

  def incrementoption
    # if option is nil then what?
    @option = nil

    Option.transaction do
      @option = Option.where(optionable_id: params[:id], optionable_type: "Job", name: params[:name]).first
      @option.lock! # Unsure if this would work in rails5
      unless (@option.nil?)
        i = (@option.value.to_i + 1)
        @option.value = i.to_s
        @option.save!
      end
    end
    
    if @option.nil? then
      respond_to do |format|
        format.xml { render :xml => "No such record", :status => 500 }
        format.html { redirect_to '/' }
      end
    else
      respond_to do |format|
        format.html { redirect_to option_path(@option) }
        format.xml  { render :xml => @option.to_xml, :status => :ok }
      end
    end
  end

end

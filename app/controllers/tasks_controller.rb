class TasksController < ApplicationController

  before_action :authenticate
  layout "main"

  def index
    if (params[:pipeline_id])
      @pipeline = Pipeline.find(params[:pipeline_id])
      @tasks    = @pipeline.tasks
    else
      @tasks    = Task.all
    end

    respond_to do |format|
      format.xml { render :xml => @tasks.to_xml }
      format.html { }
    end
  end

  def show
    @task = Task.find(params[:id])
    @pipeline = @task.pipeline
    respond_to do |format|
      format.xml { render :xml => @task.to_xml }
      format.html { }
    end

  rescue ActiveRecord::RecordInvalid

    respond_to do |format|
      format.html { redirect_to pipeline_path }
      format.xml { render :xml => @task.errors.to_xml, :status => 500 }
    end
  end

  def add_requirement
    @task = Task.find(params[:id])
    @pipeline = @task.pipeline
    @name = params[:name]
    @val = params[:value]
    #@req = Requirement.create({ :name => @name, :value => @value})
	@req = Requirement.create() do |r|
		r.name = @name
		r.value = @value
	end
    @req.task = @task
    @req.save!
    respond_to do |format|
      format.xml { render :xml => @req.to_xml }
      format.html { }
    end

  rescue ActiveRecord::RecordInvalid
    respond_to do |format|
      format.html { redirect_to pipeline_path }
      format.xml { render :xml => @task.errors.to_xml, :status => 500 }
    end
  end

  def get
    @pipeline = Pipeline.find(params[:pipeline_id])
    @task = @pipeline.tasks.build
  end

  def findbyname
    @pipeline = Pipeline.find(params[:pipeline_id])
    @task     = Task.where(name: params[:name], pipeline_id: params[:pipeline_id]).first

    if (@task.nil?)
      respond_to do |format|
        format.xml { render :xml => "No such record", :status => :ok  }
        format.html { redirect_to '/' }
      end
    else
      respond_to do |format|
        format.xml  { render :xml => @task.to_xml, :status => :ok }
        format.html { redirect_to pipeline_tasks_path(@pipeline) }
      end
    end
  end


  def create
    @pipeline = Pipeline.find(params[:pipeline_id])
    @task = @pipeline.tasks.build(params[:task])
    @task.nruns = 0;
    @task.TotalRunTime = 0;
    @task.save!

    respond_to do |format|
      format.xml  { render :xml => @task.to_xml, :status => :created }
      format.html { redirect_to pipeline_tasks_path(@pipeline) }
    end

    rescue ActiveRecord::RecordInvalid
    respond_to do |format|
      format.html { render :action => 'new' }
      format.xml  { render :xml => @task.errors.to_xml, :status => 500 }
    end
  end


  def edit
    @pipeline = Pipeline.find(params[:pipeline_id])
    @task     = Task.find(params[:id])
  end

  # Remove all masks so that a Task can safely be re-registered
  #
  def unmask
    @pipeline = Pipeline.find(params[:pipeline_id])
    @task     = Task.find(params[:id])

    @task.masks.each { |m| m.destroy  }

    respond_to do |format|
      format.html { redirect_to pipeline_tasks_path(@pipeline) }
      format.xml { head :ok }
    end

  end

  def destroy
    @pipeline = Pipeline.find(params[:pipeline_id])
    @task     = Task.find(params[:id])

    # you may not destroy the StartTask
    @task.destroy unless (@task.name.eql? 'StartTask')
    
    respond_to do |format|
      format.html { redirect_to pipeline_tasks_path(@pipeline) }
      format.xml { head :ok }
    end

  end

  def update
    @pipeline = Pipeline.find(params[:pipeline_id])
    @task     = Task.find(params[:id])
    @task.attributes = params[:task]
    @task.save!

    respond_to do |format|
      format.html { redirect_to pipeline_task_path(@pipeline, @task) }
      format.xml { render :xml => @task.to_xml, :status => :ok }
    end

    rescue ActiveRecord::RecordInvalid

    respond_to do |format|
      format.html { render :action => 'edit' }
      format.xml { render :xml => @task.errors.to_xml, :status => 500 }
    end
  end

  #
  #  SEE THE startjob in targets_controller
  #
  # called to add a job
  # requires a target and configuration in addition to a target
  #
  # BROKEN - the view in jobs/new.html.erb doesn't match the configuration
  # to the target, and it's the target that gets attached to the job.  So a
  # user can select a Target and a 'default' configuration, and then end up
  # with the wron target after all.
  #
  #
#  def startjob
#    @task      = Task.find(params[:id])
#    @target    = Target.find(params[:target][:id])
#    @pipeline  = @target.pipeline
#    @configuration = Configuration.find(params[:configuration][:id])
#    @job           = Job.create_from_task_and_config @task, @configuration
#    puts 'Job ', @job.id
#    redirect_to job_path(@job.id)
#  end

end

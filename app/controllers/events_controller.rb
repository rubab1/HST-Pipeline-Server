class EventsController < ApplicationController

  before_action :authenticate

  layout "main"

  def index
    if (params[:job_id])
      @job = Job.find(params[:job_id])
      @events    = @job.events
    else
      @events    = Event.all
    end

    respond_to do |format|
      format.xml { render :xml => @events.to_xml }
      format.html { }
    end
  end

  def show
    @event = Event.find(params[:id])
    @job = @event.job
    @jobs = Job.where(event_id: @event.id)
    @options = @event.options
    
    respond_to do |format|
      format.xml { render :xml => @event.to_xml }
      format.html { }
    end

  rescue ActiveRecord::RecordInvalid

    respond_to do |format|
      format.html { redirect_to job_path }
      format.xml { render :xml => @event.errors.to_xml, :status => 500 }
    end
  end

  def get
    @job = Job.find(params[:job_id])
    @event = @job.events.build
  end

  def new
    @job = Job.find(params[:job_id])
    @event = @job.events.build
  end


  def create
    @job = Job.find(params[:job_id])
    @event = @job.events.build(params[:event])
    @event.save!

    respond_to do |format|
      format.xml  { render :xml => @event.to_xml, :status => :created }
      format.html { redirect_to job_path(@job) }
    end

    rescue ActiveRecord::RecordInvalid
    respond_to do |format|
      format.html { render :action => 'new' }
      format.xml  { render :xml => @event.errors.to_xml, :status => 500 }
    end
  end


  def edit
    @job = Job.find(params[:job_id])
    @event     = Event.find(params[:id])
  end

  def destroy
    @job = Job.find(params[:job_id])
    @event     = Event.find(params[:id])
    @event.destroy
    
    respond_to do |format|
      format.html { redirect_to job_events_path(@job) }
      format.xml { head :ok }
    end

  end

  def update
    @job = Job.find(params[:job_id])
    @event     = Event.find(params[:id])
    @event.attributes = params[:event]
    @event.save!

    respond_to do |format|
      format.html { redirect_to job_event_path(@job, @event) }
      format.xml { render :xml => @event.to_xml, :status => :ok }
    end

    rescue ActiveRecord::RecordInvalid

    respond_to do |format|
      format.html { render :action => 'edit' }
      format.xml { render :xml => @event.errors.to_xml, :status => 500 }
    end
  end

  #
  # Once an event is created in the Pipeline
  # calling "fire" causes the masking to be checked and new jobs launched
  #
  def fire
    @event = Event.find(params[:id])
	@job = @event.job

    @event.fire

    respond_to do |format|
      format.html { redirect_to job_event_path(@job, @event) }
      format.xml { render :xml => @event.to_xml, :status => :ok }
    end

    rescue ActiveRecord::RecordInvalid

    respond_to do |format|
      format.html { render :action => 'edit' }
      format.xml { render :xml => @event.errors.to_xml, :status => 500 }
    end

  end

  def setoption
    # @event = Event.find(params[id])
    @option = Option.where(optionable_id: params[:id], optionable_type: "Event", name: params[:name]).first
    if (@option.nil?)
      @event = Event.find(params[:id])
      @option = @event.options.build
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
    @options = Option.where(optionable_id: params[:id], optionable_type: "Event")

    respond_to do |format|
      format.html { }
      format.xml  { render :xml => @options.to_xml, :status => :ok }
    end
  end

end

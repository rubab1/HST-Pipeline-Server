class MasksController < ApplicationController
  
  before_action :authenticate
  layout "main"

  def index
    @task = Task.find(params[:task_id])
    @masks    = @task.masks
    respond_to do |format|
      format.xml { render :xml => @masks.to_xml }
      format.html { }
    end
  end

  def show
    @task = Task.find(params[:task_id])
    @mask = Mask.find(params[:id])

    respond_to do |format|
      format.xml { render :xml => @mask.to_xml }
      format.html { }
    end

  rescue ActiveRecord::RecordInvalid

    respond_to do |format|
      format.html { redirect_to task_path(@task) }
      format.xml { render :xml => @mask.errors.to_xml, :status => 500 }
    end
  end

  def destroy
    @task = Task.find(params[:task_id])
    @mask = Mask.find(params[:id])
    @mask.destroy

    respond_to do |format|
      format.html { redirect_to task_masks_path(@task) }
      format.xml { head :ok }
    end
  end

  def edit
    @task = Task.find(params[:task_id])
    @mask = Mask.find(params[:id])
  end

  def get
    @task = Task.find(params[:task_id])
    @mask = @task.masks.build
  end

  def create
    @task = Task.find(params[:task_id])
    @mask = @task.masks.build(params[:mask])
    @mask.save!

    respond_to do |format|
      format.xml { render :xml => @mask.to_xml, :status => :created }
      format.html { redirect_to task_path(@task) }
    end

    rescue ActiveRecord::RecordInvalid
    respond_to do |format|
      format.html { render :action => 'new' }
      format.xml  { render :xml => @mask.errors.to_xml, :status => 500 }
    end
  end

  def update
    @task = Task.find(params[:task_id])
    @mask = Mask.find(params[:id])
    @mask.attributes = params[:mask]
    @mask.save!

    respond_to do |format|
      format.html { redirect_to task_mask_path(@task, @mask) }
      format.xml { render :xml => @mask.to_xml, :status => :ok }
    end

    rescue ActiveRecord::RecordInvalid

    respond_to do |format|
      format.html { render :action => 'edit' }
      format.xml { render :xml => @mask.errors.to_xml, :status => 500 }
    end
  end

end

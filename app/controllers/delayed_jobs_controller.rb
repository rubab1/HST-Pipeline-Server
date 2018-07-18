class DelayedJobsController < ApplicationController

  before_action :authenticate
  layout "main"

  def index
    @djobs = InfraDelayedJob.all
    respond_to do |format|
      format.xml { render :xml => @djobs.to_xml }
      format.html { }
    end
  end

  def show
    djob_id = params[:id]
    @djob = InfraDelayedJob.find(djob_id)
    respond_to do |format|
      format.xml { render :xml => @djob.to_xml }
      format.html { }
    end
  rescue ActiveRecord::RecordInvalid
    respond_to do |format|
      format.html { 
        flash[:error] = "Problem finding delayed job #{djob_id}"
        redirect_to '/delayed_jobs/' 
      }
    end
  end

  def delete
    djob_id = params[:id]
    @djob = InfraDelayedJob.find(djob_id)
    @djob.delete
    respond_to do |format|
      format.html { 
        flash[:notice] = "Deleted Delayed Job #{djob_id}"
        redirect_to '/delayed_jobs/' 
      }
    end
  rescue ActiveRecord::RecordInvalid
    respond_to do |format|
      format.html { 
        flash[:error] = "Problem finding delayed job #{djob_id}"
        redirect_to '/delayed_jobs/' 
      }
    end
  end


end

class ParametersController < ApplicationController

  before_action :authenticate
  layout "main"

  def show
    @parameter = Parameter.find(params[:id])
    respond_to do |format|
      format.xml { render :xml => @parameter.to_xml }
      format.html { }
    end

  rescue ActiveRecord::RecordInvalid

    respond_to do |format|
      format.html {  }
      format.xml { render :xml => @parameter.errors.to_xml, :status => 500 }
    end
  end

  def index
  end

  def get
    @configuration = ::Configuration.find(params[:configuration_id])
    @parameter = @configuration.parameters.build
  end

  def getauth
  end

  def create
  end

  def update
    @parameter   = Parameter.find(params[:id])
    @parameter.name = params[:parameter_name]
    @parameter.volatile = params[:parameter_volatile]
    @parameter.group = params[:parameter_group]
    @parameter.value = params[:parameter_value]
    @parameter.description = params[:parameter_description]
    @parameter.ptype = params[:parameter_ptype]

    @parameter.save!
    respond_to do |format|
      format.xml { render :xml => @parameter.to_xml }
      format.html { }
    end

  end
  
  def destroy
    @config      = ::Configuration.find(params[:configuration_id])
    @parameter   = Parameter.find(params[:id])
    @parameter.destroy

    respond_to do |format|
      format.html { redirect_to configuration_path(@config) }
      format.xml { head :ok }
    end
  end

  def by_name
    @config = ::Configuration.find(params[:configuration_id])
    @parameter = Parameter.where(name: params[:name])
    respond_to do |format|
      format.xml { render :xml => @parameter.to_xml }
      format.html { }
    end

  rescue ActiveRecord::RecordInvalid

    respond_to do |format|
      format.html {  }
      format.xml { render :xml => @parameter.errors.to_xml, :status => 500 }
    end
  end

  def by_configuration
    @config = ::Configuration.find(params[:configuration_id])
    @parameters = @config.parameters
    respond_to do |format|
      format.xml { render :xml => @parameters.to_xml }
      format.html { }
    end

  rescue ActiveRecord::RecordInvalid

    respond_to do |format|
      format.html {  }
      format.xml { render :xml => @parameter.errors.to_xml, :status => 500 }
    end
  end

end

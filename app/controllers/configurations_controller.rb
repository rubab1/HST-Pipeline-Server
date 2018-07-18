class ::ConfigurationsController < ApplicationController

  before_action :authenticate

  layout "main"

  def index
    if (params[:target_id])
      @target = Target.find(params[:target_id])
      @configurations    = @target.configurations
    else
      @configurations    = ::Configuration.all
    end

    respond_to do |format|
      format.xml { render :xml => @configurations.to_xml }
      format.html { }
    end
  end

  def show
    @configuration = ::Configuration.find(params[:id])
    @target = @configuration.target
    respond_to do |format|
      format.xml  { render :xml => @configuration.to_xml }
      format.html { }
    end

  rescue ActiveRecord::RecordInvalid

    respond_to do |format|
      format.html { redirect_to target_path }
      format.xml { render :xml => @configuration.errors.to_xml, :status => 500 }
    end
  end

  def get
    @target = Target.find(params[:target_id])
    @configuration = @target.configurations.build
  end


  def create
    @target = Target.find(params[:target_id])
    @configuration = @target.configurations.build(params[:configuration])
    @configuration.save!

    respond_to do |format|
      format.xml  { render :xml => @configuration.to_xml, :status => :created }
      format.html { redirect_to target_configurations_path(@target) }
    end

  rescue ActiveRecord::RecordInvalid
    respond_to do |format|
      format.html { render :action => 'new' }
      format.xml  { render :xml => @configuration.errors.to_xml, :status => 500 }
    end
  end


  def edit
    @target = Target.find(params[:target_id])
    @configuration     = ::Configuration.find(params[:id])
  end

  def destroy
    @target = Target.find(params[:target_id])
    @configuration     = ::Configuration.find(params[:id])
    @configuration.destroy
    
    respond_to do |format|
      format.html { redirect_to target_configurations_path(@target) }
      format.xml { head :ok }
    end

  end

  def update
    @target = Target.find(params[:target_id])
    @configuration     = ::Configuration.find(params[:id])
    @configuration.attributes = params[:configuration]
    @configuration.save!

    respond_to do |format|
      format.html { redirect_to target_configuration_path(@target, @configuration) }
      format.xml { render :xml => @configuration.to_xml, :status => :ok }
    end

  rescue ActiveRecord::RecordInvalid

    respond_to do |format|
      format.html { render :action => 'edit' }
      format.xml { render :xml => @configuration.errors.to_xml, :status => 500 }
    end
  end


  def getparameters
    @parameters = Parameter.where(configuration_id: params[:id])

    respond_to do |format|
      format.html { }
      format.xml  { render :xml => @parameters.to_xml, :status => :ok }
    end
  end

  def getparameter
    @parameter = Parameter.where(configuration_id: params[:id], name: params[:pname]).first

    if @parameter.nil? then
      respond_to do |format|
        format.xml { render :xml => "No such record", :status => :ok }
        format.html { redirect_to '/' }
      end
    else
      respond_to do |format|
        format.html { }
        format.xml  { render :xml => @parameter.to_xml, :status => :ok }
      end
    end
  end

  def addparameter
    @configuration = ::Configuration.find(params[:id])

    # ensure parameter doesn't previously exist
    @parameter = Parameter.where(configuration_id: params[:id], name: params[:parameter_name]).first

    if (@parameter.nil?) then
      @parameter = @configuration.parameters.build(:name=>params[:parameter_name],
        :value=>params[:parameter_value], :ptype=>params[:parameter_ptype],
        :group=>params[:parameter_group], :description=>params[:parameter_description],
        :configuration_id=>@configuration.id, :volatile=>params[:parameter_volatile])
    else
      @parameter.name = params[:parameter_name]
      @parameter.value = params[:parameter_value]
      @parameter.ptype = params[:parameter_ptype]
      @parameter.group = params[:parameter_group]
      @parameter.volatile = params[:parameter_volatile]
      @parameter.description = params[:parameter_description]
    end
    @parameter.save!
    
    logger.debug("configurations:addparameter parameter=#{@parameter.inspect}")
    respond_to do |format|
      format.html { }
      format.xml  { render :xml => @parameter.to_xml, :status => :ok }
    end
  end

  def dataproducts
    @configuration = ::Configuration.find(params[:id])
    @dps = @configuration.data_products
    respond_to do |format|
      format.html {  }
      format.xml { render :xml => @dps.to_xml, :status => :ok }
    end
  end

end

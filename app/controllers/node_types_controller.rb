class NodeTypesController < ApplicationController

  before_action :authenticate
  layout "main"

  def new
  end

  def show
    @types = NodeType.get_active_node_types
    logger.debug("get_types : #{@types.inspect}")

    respond_to do |format|
      format.xml { render :xml => @types.to_xml }
      format.json  { render :json => @types.to_json }
      format.html { }
    end

  rescue ActiveRecord::RecordInvalid

    respond_to do |format|
      format.html { redirect_to nodes_path }
      format.xml { render :xml => @types.errors.to_xml, :status => 500 }
    end
  end

  def index
    show
  end

  def get
    id = params[:id]
    @types = NodeType.where(id: id, status: 1).first
  end


  def edit
  end

  def destroy
  end


end

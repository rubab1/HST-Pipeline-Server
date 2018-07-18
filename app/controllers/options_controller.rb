class OptionsController < ApplicationController

  before_action :authenticate
  layout "main"

  def show
    @option            = Option.find(params[:id])

    respond_to do |format|
      format.xml { render :xml => @option.to_xml  }
      format.html { }
    end

  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html {  }
      format.xml { render :xml =>  "No such record", :status => 500 }
    end
  end

  def index
  end

end

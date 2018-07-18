class DataProductsController < ApplicationController

  before_action :authenticate

  layout "main"

  def getdefault(c)
    @d = c.data_products.build

    @d.filename        = ""
    @d.relativepath    = ""
    @d.suffix          = ""
    @d.data_type       = "unknown"
    @d.subtype         = ""
    @d.group           = "default"
    @d.source          = ""

    @d.binfiltercommon = 0
    @d.binfiltermiddle = 0
    @d.binfilternarrow = 0
    @d.ra              = 0
    @d.dec             = 0
    @d.pointing_angle  = 0

    @d.s3bucket        = ""
    @d.s3objectid      = ""
    @d.s3region        = "US East"

    @d.locktype        =""

  end

  def index
    @target = Target.find(params[:target_id])
    @configuration = ::Configuration.find(params[:configuration_id])
    @data = @configuration.data_products
  end

  def show
    @data_product = DataProduct.find(params[:id])
    # logger.debug("show data_product = #{@data_product.inspect}")
    @conf = @data_product.configuration
    # logger.debug("show conf = #{@conf.inspect}")
    @target = @conf.target
    # logger.debug("show target = #{@target.inspect}")

    @options = @data_product.options

    respond_to do |format|
      format.xml { render :xml => @data_product.to_xml(:include => {:options =>{:only =>[:id]}}) }
      format.html { }
    end

  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.xml { render :xml => "No such record", :status => 500 }
      format.html { redirect_to '/' }
    end

  rescue ActiveRecord::RecordInvalid

    respond_to do |format|
      format.html { redirect_to target_path(@target) }
      format.xml { render :xml => @data_product.errors.to_xml, :status => 500 }
    end
  end

  def delete
    begin
      @target = Target.find(params[:target_id])
      @configuration = ::Configuration.find(params[:configuration_id])
      @data = @configuration.data_products
      logger.debug("delete data_product = #{@data.inspect}")
      id = @data.id 
      # @data.delete
      respond_to do |format|
        format.xml { render :xml => true.to_xml }
        format.json { render :json => true.to_json }
        format.html {
          flash[:info] = "Data Product : #{id} deleted"
          redirect_to :action => "/targets/#{@target.id}/configurations/#{@configuration.id}/data_products"
        }
      end
    rescue Exception => e
      logger.warn("delete Error : #{e.inspect}")
      flash[:error] = "Error : #{e.inspect}"
      redirect_to :action => "/targets/#{@target.id}/configurations/#{@configuration.id}/data_products"
    end
  end

  def new
    @c = ::Configuration.find(params[:configuration_id])
    @t = @c.target
    @d = @c.data_products.build
  end

  def create
    @c = ::Configuration.find(params[:configuration_id])
    @t = @c.target
    @d = @c.data_products.build(params[:data_product])

    @d.save!

    respond_to do |format|
      format.html { redirect_to target_configuration_data_product_path(@t,@c,@d) }
      format.xml  { render :xml => @d.to_xml }
    end

  rescue ActiveRecord::RecordInvalid
    respond_to do |format|
      format.html { render :action => 'new' }
      format.xml  { render :xml => @d.errors.to_xml, :status => 500 }
    end
  end

  # different callers to update may send different collections of parameters
  # so only update those that have been set
  #
  def update
    @d = DataProduct.where(id: params[:data_product][:id]).first

    @d.filename         = params[:data_product][:filename]         unless params[:data_product][:filename].nil?
    @d.relativepath     = params[:data_product][:relativepath]     unless params[:data_product][:relativepath].nil?
    @d.suffix           = params[:data_product][:suffix]           unless params[:data_product][:suffix].nil?
    @d.data_source      = params[:data_product][:data_source]      unless params[:data_product][:data_source].nil?
    @d.s3bucket         = params[:data_product][:s3bucket]         unless params[:data_product][:s3bucket].nil?
    @d.s3objectid       = params[:data_product][:s3objectid]       unless params[:data_product][:s3objectid].nil?
    @d.group            = params[:data_product][:group]            unless params[:data_product][:group].nil?
    @d.configuration_id = params[:data_product][:configuration_id] unless params[:data_product][:configuration_id].nil?

    @d.data_type        = params[:data_product][:data_type]        unless params[:data_product][:data_type].nil?
    @d.subtype          = params[:data_product][:subtype]          unless params[:data_product][:subtype].nil?
    @d.ra               = params[:data_product][:ra]               unless params[:data_product][:ra].nil?
    @d.dec              = params[:data_product][:dec]              unless params[:data_product][:dec].nil?
    @d.pointing_angle   = params[:data_product][:pointing_angle]   unless params[:data_product][:pointing_angle].nil?

    @d.binfiltercommon  = params[:data_product][:binfiltercommon]  unless params[:data_product][:binfiltercommon].nil?
    @d.binfiltermiddle  = params[:data_product][:binfiltermiddle]  unless params[:data_product][:binfiltermiddle].nil?
    @d.binfilternarrow  = params[:data_product][:binfilternarrow]  unless params[:data_product][:binfilternarrow].nil?

    @d.save!


    respond_to do |format|
      format.html { redirect_to target_configuration_data_product_path(@t,@c,@d) }
      format.xml  { render :xml => @d.to_xml }
    end

  rescue ActiveRecord::RecordInvalid
    respond_to do |format|
      format.html { render :action => 'new' }
      format.xml  { render :xml => @d.errors.to_xml, :status => 500 }
    end
  end

  #
  # requires a configuration and a data product path
  # if the configuration contains a data product with that
  # path, then the DP is updated, otherwise a new one is created
  # In either case, the current DP is returned.
  #
  def create_or_update
    @c = ::Configuration.find(params[:configuration_id])
    @t = @c.target
    @p = params[:data_product][:relativepath]

    @d = DataProduct.where(id: params[:data_product][:id]).first
    
    if @d.nil?
      @d = @c.data_products.build(params[:data_product])
      @d.save!

      # logger.debug(@d.inspect)
      respond_to do |format|
        format.html { redirect_to target_configuration_data_product_path(@t,@c,@d) }
        format.xml  { render :xml => @d.to_xml }
      end
    else
      @d.filename         = params[:data_product][:filename]         unless params[:data_product][:filename].nil?
      @d.relativepath     = params[:data_product][:relativepath]     unless params[:data_product][:relativepath].nil?
      @d.suffix           = params[:data_product][:suffix]           unless params[:data_product][:suffix].nil?
      @d.data_source      = params[:data_product][:data_source]      unless params[:data_product][:data_source].nil?
      @d.s3bucket         = params[:data_product][:s3bucket]         unless params[:data_product][:s3bucket].nil?
      @d.s3objectid       = params[:data_product][:s3objectid]       unless params[:data_product][:s3objectid].nil?
      @d.group            = params[:data_product][:group]            unless params[:data_product][:group].nil?
      @d.configuration_id = params[:data_product][:configuration_id] unless params[:data_product][:configuration_id].nil?

      @d.data_type        = params[:data_product][:data_type]        unless params[:data_product][:data_type].nil?
      @d.subtype          = params[:data_product][:subtype]          unless params[:data_product][:subtype].nil?
      @d.ra               = params[:data_product][:ra]               unless params[:data_product][:ra].nil?
      @d.dec              = params[:data_product][:dec]              unless params[:data_product][:dec].nil?
      @d.pointing_angle   = params[:data_product][:pointing_angle]   unless params[:data_product][:pointing_angle].nil?

      @d.binfiltercommon  = params[:data_product][:binfiltercommon]  unless params[:data_product][:binfiltercommon].nil?
      @d.binfiltermiddle  = params[:data_product][:binfiltermiddle]  unless params[:data_product][:binfiltermiddle].nil?
      @d.binfilternarrow  = params[:data_product][:binfilternarrow]  unless params[:data_product][:binfilternarrow].nil?

      @d.save!
      # logger.debug(@d.inspect)
      respond_to do |format|
        format.html { redirect_to target_configuration_data_product_path(@t,@c,@d) }
        format.xml  { render :xml => @d.to_xml }
      end
    end
  end

  def updatefilters
    @d = DataProduct.find_by_id(params[:data_product][:id])

    @d.binfiltercommon     = params[:data_product][:binfiltercommon]  unless params[:data_product][:binfiltercommon].nil?
    @d.binfiltermiddle     = params[:data_product][:binfiltermiddle]  unless params[:data_product][:binfiltermiddle].nil?
    @d.binfilternarrow     = params[:data_product][:binfilternarrow]  unless params[:data_product][:binfilternarrow].nil?

    @d.save!

    respond_to do |format|
      format.html { redirect_to target_configuration_data_product_path(@t,@c,@d) }
      format.xml  { render :xml => @d.to_xml }
    end

  rescue ActiveRecord::RecordInvalid
    respond_to do |format|
      format.html { render :action => 'new' }
      format.xml  { render :xml => @d.errors.to_xml, :status => 500 }
    end
  end

  def edit
    @d     = DataProduct.find(params[:id])
  end

  def destroy
    @d = DataProduct.find(params[:id])
    @t = @d.configuration.target
    @d.destroy

    respond_to do |format|
      format.html { redirect_to target_path(@t) }
      format.xml { head :ok }
    end

  end

  #
  # returns a collection of DataProducts based on ANDED parameters
  # 
  def findbyparameters
    
    ps = []
    params.each do |k,v|
      # logger.info( "parameter #{k}  #{v}")
      if k =~ /^(group|configuration_id|relativepath|suffix|dataType|dataSource|subtype)$/
         ps << 'data_products.'+k + " = '" + v + "' ";
      end
      if k =~ /^(filename)$/
         ps << 'data_products.'+k + " like '" + v + "' ";
      end
    end
    query = "SELECT * from data_products WHERE " + ps.join(" AND ")
    # logger.info(" the query: #{query} ")

     @dps = DataProduct.find_by_sql query


    respond_to do |format|
      format.html {  }
      format.xml { render :xml => @dps.to_xml, :status => :ok }
    end

  end

  #
  # repeats findbyparameters, but for all targets and all configurations
  # in a pipeline
  #
  def  findallbyparameters

    ps  = []
    pid = 0
    params.each do |k,v|
      # logger.info( "parameter #{k}  #{v}")
      if k =~ /^(group|suffix|dataType|dataSource|subtype)$/
         ps << 'data_products.'+k + " = '" + v + "' ";
      end
      if k =~ /^(filename)$/
         ps << 'data_products.'+k + " like '" + v + "' ";
      end
      if k =~ /(^(pipeline_id)$)/
        pid = v;
      end
    end
    query = "SELECT data_products.* from data_products, targets, configurations WHERE targets.pipeline_id="+pid+" AND configurations.target_id = targets.id AND data_products.configuration_id = configurations.id AND " + ps.join(" AND ")
    # logger.info(" the query: #{query} ")

     @dps = DataProduct.find_by_sql query


    respond_to do |format|
      format.html {  }
      format.xml { render :xml => @dps.to_xml, :status => :ok }
    end

  end



  def setoption
    @option = Option.where(optionable_id: params[:id], optionable_type: "DataProduct", name: params[:name]).first
    if (@option.nil?)
      @dp = DataProduct.find(params[:id])
      @option = @dp.options.build
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
    @options = Option.where(optionable_id: params[:id], optionable_type: "DataProduct")

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

  # returns the unique filters for some specified configuration and group
  def getuniquefilters
    configurationid = params[:configuration_id]
    group           = params[:group]

    query = "select BIT_OR(binfiltercommon) AS common, BIT_OR(binfiltermiddle) AS middle, BIT_OR(binfilternarrow) AS narrow  from data_products where configuration_id=#{configurationid} and data_products.group='#{group}'"

    @result = DataProduct.find_by_sql query
    # logger.info(" the query: #{query} ")
    # logger.info(" the result: #{@result[0].common} #{@result[0].middle} #{@result[0].narrow} ")
   
    @mylist = [ {:common => @result[0].common, :middle => @result[0].middle, :narrow => @result[0].narrow} ] 

    # logger.info("RUBAB: @mylist.to_xml(:root => 'records') yields: \n #{@mylist.to_xml(:root => 'records')}")
    
    respond_to do |format|
      format.html {  }
      format.xml { render :xml => @mylist.to_xml(:root => 'records'), :status => :ok }
    end

  end

  #
  # this is way unsafe.  need a better approach someday soon!
  #
  #
  # sort out a tag request, including special tags such as filter, type,
  # subtype, etc
  #
  def findbytags
      # logger.info( "\n\n\n\n>>> findbytags <<<\n\n")

    # We generate queries that are like this:
    #    select DISTINCT `data_products`.*  FROM `data_products`
    #        INNER JOIN `options`
    #        ON `options`.optionable_id = `data_products`.id
    #          AND `options`.optionable_type='DataProduct'
    #          AND `options`.value='NORMAL'
    #        WHERE `data_products`.configuration_id=66
    #          AND `data_products`.group="raw"
    #          AND (
    #               (`data_products`.binfiltercommon & ( 1048576|1073741824 ) )
    #                OR
    #               (`data_products`.binfiltermiddle & ( 1048576) )
    #              );
    #
    #

    ps  = []
    ops = []
    fs  = []

    configurationid = params[:configuration_id]
    group           = params[:group]

    fs << "(`data_products`.binfiltercommon & ( #{params[:bfc]} ) )" unless params[:bfc].nil?
    fs << "(`data_products`.binfiltermiddle & ( #{params[:bfm]} ) )" unless params[:bfm].nil?
    fs << "(`data_products`.binfilternarrow & ( #{params[:bfn]} ) )" unless params[:bfn].nil?

    # first, pull out the parameters and tags
    params.each do |k,v|
      if k =~ /^(configuration_id|pipeline_id|format|authenticity_token|action|sig|controller|ts|bfc|bfn|bfm)$/
        # ignore
      elsif k =~ /^(group|relativepath|suffix|dataType|dataSource|subtype)$/
        # logger.info( "parameter #{k}  #{v}")
        ps << 'data_products.'+k + " = '" + v + "' ";
      elsif k =~ /^(filename)$/
        # logger.info( "parameter #{k}  #{v}")
        ps << 'data_products.'+k + " LIKE '" + v + "' ";
      else
        # logger.info( "parameter #{k}  #{v}")
        if k=~ /^filter/
          fs << v
        else
          ops << 'options.name="'+ k + '" and options.value="' + v + '"';
        end
        # options here
      end

    end

    query = " WHERE data_products.configuration_id=" + configurationid
    ps.each do |p|
      query = query + " AND " + p
    end

    # ANY of the filter sets are logical ORed
    # but bitwise ANDed within the field
    #
    if (fs.length > 0) then
      fq = fs.join(" OR ")
      query = query + " AND ( #{fq} ) "
    end

    subquery = ""
    if (ops.size > 0)
      subquery = " INNER JOIN `options` " \
        + " ON `options`.optionable_id = `data_products`.id " \
        + " AND `options`.optionable_type='DataProduct' "
      ops.each { |o| subquery = subquery + " AND " + o }
    end

    query = 'select DISTINCT `data_products`.*  FROM `data_products` ' + subquery + query
    # logger.info( "QUERY:  #{query}")
    # logger.info( "n\n=== findbytags ===\n\n\n\n")

    @dps = DataProduct.find_by_sql query


    respond_to do |format|
      format.html {  }
      format.xml { render :xml => @dps.to_xml, :status => :ok }
    end

  end

  #
  # grants a lock for the number of seconds requested
  # if the lock is available, or if already owned by the requesting node
  #
  def lock
    nodeid  = params[:node]
    reqsecs = params[:duration]
    reqtype = params[:lock]

    DataProduct.transaction do
      @dp     = DataProduct.find(params[:id])
      @dp = @dp.attemptlock(nodeid, reqtype, reqsecs)
    end

    respond_to do |format|
      format.xml { render :xml => @dp.to_xml(:include => {:options =>{:only =>[:id]}}) }
      format.html { }
    end

  end

  def unlock
    nodeid  = params[:node]

    DataProduct.transaction do
      @dp     = DataProduct.find(params[:id])
      @dp.releaselock(nodeid)
    end

    respond_to do |format|
      format.xml { render :xml => @dp.to_xml(:include => {:options =>{:only =>[:id]}}) }
      format.html { }
    end

  end

end

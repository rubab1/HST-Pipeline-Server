class PipelinesController < ApplicationController

  include SshHelper
  include Ec2Helper

  before_action :authenticate

  layout 'main'

  MAX_RECURR_DEPTH=100

  def index
   
    @pipelines = nil
    if @authn_user.is_admin
       @pipelines = Pipeline.order('user_id, created_at ASC')
    else
       @pipelines = Pipeline.where(user_id: @authn_user.id).order('created_at ASC')
    end
    states = PipelineState.where(status: 1)

    @pipeline_states = []
    @pipeline_state_hold = nil
    @pipeline_state_ready = nil
    states.each do |state|
      @pipeline_states[state.id] = state.name
      @pipeline_state_ready = state.id if state.name == 'ready'
      @pipeline_state_hold = state.id if state.name == 'hold'
    end
    # logger.debug("pipeline_states=#{@pipeline_states.inspect}")
    respond_to do |format|
      format.xml { render :xml => @pipelines.to_xml }
      format.html { }
    end
  end

  def show
    begin
      @pipeline = Pipeline.find(params[:id])
      # logger.debug("pipeline=#{@pipeline.inspect}")

      @pipeline_state = PipelineState.find @pipeline.state_id 

      @showTree = params[:showTree]

      @pipeline_tree_tree = "<a href=\"/pipelines/#{@pipeline.id}/?showTree=1\">Show Tree</a>\n";
      if (@showTree.to_i > 0 && params[:format] != 'xml') 
        @pipeline_all_tasks = Task.where(pipeline_id: @pipeline.id).order('id ASC')
        # logger.debug("pipeline_all_tasks=#{@pipeline_all_tasks.inspect}")
        @pipeline_all_jobs = Job.where(["jobs.task_id in ( select tasks.id from tasks where pipeline_id = ?)", @pipeline.id]).order('id ASC')
        # logger.debug("pipeline_all_jobs=#{@pipeline_all_jobs.inspect}")
        @pipeline_all_events = Event.where(["events.job_id IN ( SELECT jobs.id FROM jobs WHERE jobs.task_id IN ( SELECT tasks.id FROM tasks WHERE pipeline_id = ?))", @pipeline.id]).order('id ASC')
        # logger.debug("pipeline_all_events=#{@pipeline_all_events.inspect}")
        @pipeline_tree_tree = "\n<ul>\n";
        @pipeline_tree_tree += "<li id=\"jobs\">\n";
        @pipeline_tree_tree += "<a href=\"#\" onclick='return false;'>Events/Jobs|Tasks</a>\n";
        @visited_jobs = []
        @visited_events = []
        last_seed_job = nil

        if (!@pipeline_all_jobs.nil? && !@pipeline_all_tasks.nil?)
          @seed_task = Task.where(name: 'StartTask', pipeline_id: @pipeline.id).first
          # logger.debug("@seed_task=#{@seed_task.inspect}")
          if (!@seed_task.nil?)
            task_name = @seed_task.name
            task_id = (@seed_task.nil?) ? 'NO_TASK?' : @seed_task.id
            @seed_jobs = Job.where(task_id: @seed_task.id)
            # logger.debug("@seed_jobs=#{@seed_jobs.inspect}")
            if (!@seed_jobs.nil?)
              @pipeline_tree_tree += "<ul>\n";
              @seed_jobs.each do |seed_job|
                last_seed_job = seed_job
                _render_pipeline_jobs_tree_branch(seed_job,0)
              end # each job
              @pipeline_tree_tree += "</ul>\n";
            end # if seed_jobs
          end # if @seed_tasks
       end
       @pipeline_tree_tree += "</li>\n";   
       @pipeline_tree_tree += "<li id=\"targets\">\n";
       @pipeline_tree_tree += "<a href=\"#\" onclick='return false;' >Targets</a>\n";

       if (!@pipeline.targets.nil?)
         @pipeline_tree_tree += "<ul>\n";
         @pipeline.targets.each do |t| 
           @pipeline_tree_tree += "<li id=\"target_#{t.id}\">\n";
           @pipeline_tree_tree += "<a href=\"#\" onclick=\"showDetails('target',#{t.id},'#{CGI.escapeHTML(t.to_json)}'); return false;\">#{t.id} : #{t.name}</a>\n";
           @pipeline_tree_tree += "</li>\n";
         end
         @pipeline_tree_tree += "</ul>\n";
       end
       
       @pipeline_tree_tree += "</li>\n";
       @pipeline_tree_tree += "<li id=\"nodes\">\n";
       @pipeline_tree_tree += "<a href=\"#\" onclick='return false;' >Nodes</a>\n";
       
       if (!@pipeline.nodes.nil?)
         @pipeline_tree_tree += "<ul>\n";
         @pipeline.nodes.each do |t| 
           @pipeline_tree_tree += "<li id=\"node_#{t.id}\">\n";
           @pipeline_tree_tree += "<a href=\"#\" onclick=\"showDetails('node',#{t.id}, '#{CGI.escapeHTML(t.to_json)}'); return false;\">#{t.id} : #{t.name}</a>\n";
           @pipeline_tree_tree += "</li>\n";
         end
         @pipeline_tree_tree += "</ul>\n";
       end
       @pipeline_tree_tree += "</li>\n";
 
       @pipeline_tree_tree += "</ul>\n";
       # initially_open_string = (last_seed_job.nil?) ? '' : "\"jobs\", \"job_#{last_seed_job.id}\""
       initially_open_string = (last_seed_job.nil?) ? '' : "\"jobs\""
  
               # "json_data: [ ajax: { url: \"/api/v1/\" } ], " +
               # "plugins: [ \"themes\", \"json_data\"  ] , " +
       @pipeline_tree_config = "{  core: { "+
                  "initially_open: [ #{initially_open_string} ] , " +
                " }," +
               "plugins: [ \"themes\", \"html_data\"  ] , " +
               "themes: { url: \"/themes/apple/style.css\" , theme: \"apple\", dots: true }," + 
               " }";
  
       @pipeline_tree_initial_actions = "$(\"#pipeline_tree\").jstree( #{@pipeline_tree_config} );"
       if ( !last_seed_job.nil? )
        @pipeline_tree_initial_actions += "\nijob = $(\"#job_#{last_seed_job.id}\"); $(\"#pipeline_tree\").jstree(\"open_all\", ijob);"
       end

        @pipeline_tree_buttons = "<div id=\"tree_control_buttons\">"

      	@pipeline_tree_buttons += "<a href=\"#\" onclick='$(\"#pipeline_tree\").jstree(\"open_all\", $(\"#jobs\")); return false;'>Open All Jobs</a><br>"
        @pipeline_tree_buttons += "<a href=\"#\" onclick='$(\"#pipeline_tree\").jstree(\"close_all\", $(\"#jobs\"))'; return false;>Close All Jobs</a><br>"
        @pipeline_tree_buttons += "<a href=\"#\" onclick='$(\"#pipeline_tree\").jstree(\"open_all\", $(\"#targets\"))'; return false;>Open All Targets</a><br>"
        @pipeline_tree_buttons += "<a href=\"#\" onclick='$(\"#pipeline_tree\").jstree(\"close_all\", $(\"#targets\"))'; return false;>Close All Targets</a><br>"
        @pipeline_tree_buttons += "<a href=\"#\" onclick='$(\"#pipeline_tree\").jstree(\"open_all\", $(\"#nodes\"))'; return false;>Open All Nodes</a><br>"
        @pipeline_tree_buttons += "<a href=\"#\" onclick='$(\"#pipeline_tree\").jstree(\"close_all\", $(\"#nodes\"))'; return false;>Close All Nodes</a><br>"
        @pipeline_tree_buttons += "</div>"

      end
      respond_to do |format|
        format.xml { render :xml => @pipeline.to_xml(:include => {:tasks =>{:only =>[:id]}}) }
        format.html { }
      end

    rescue ActiveRecord::RecordInvalid
      respond_to do |format|
        format.html { redirect_to '/' }
        format.xml { render :xml => @pipeline.errors.to_xml, :status => 500 }
      end

    rescue ActiveRecord::RecordNotFound
      respond_to do |format|
        format.xml { render :xml => "No such record", :status => :ok }
        format.html { redirect_to '/' }
      end
    end

  end


  def target
    begin
      @pipeline = Pipeline.find(params[:id])
      @name = params[:name]

      # logger.debug("Name: #{@pipeline.name}")
      
      @target = Target.where(pipeline_id: params[:id], name: params[:name]).first

      unless @target.nil?
        respond_to do |format|
          format.xml { render :xml => @target.to_xml(:include => {:configurations =>{:only =>[:id]}}) }
          format.html { @pipeline }
        end
      else
        respond_to do |format|
          format.xml { render :xml => "No such record", :status => :ok }
          format.html { redirect_to pipeline_path }
        end
      end

    rescue NoMethodError
      respond_to do |format|
        format.html { redirect_to pipeline_path }
        format.xml { render :xml => @pipeline.errors.to_xml, :status => 500 }
      end

    rescue ActiveRecord::RecordInvalid
      respond_to do |format|
        format.xml { render :xml => "No such record", :status => :ok }
        format.html { redirect_to pipeline_path }
      end
    end
  end

  #
  # Provides the initial "start" jobs registered with this pipeline
  #
  # TODO: fix this method ... look at void_new_jobs in pipeline model for task_ids from pipeline_id
  # and get list of target_ids, and then use Job.find_by_sql ...
  # ... ActiveRecord::Base.sanitize(f1) ...
  # ... jjj.task_id in (SELECT ttt.id FROM tasks ttt WHERE  ttt.pipeline_id = #{self.id})
  def jobs
    @pipeline = Pipeline.find(params[:id])
    @jobs = @pipeline.tasks.jobs # NOTE: this does NOT work ... ?
  end

  def void_new_jobs
    # TODO:  authZ  - can the user do this to this pipeline ?
    pipeline_id = params[:id]
    # "select * from jobs jjj where jjj.task_id in (SELECT ttt.id FROM `tasks` ttt WHERE  pipeline_id = 75)"
    begin
      @pipeline = Pipeline.find(params[:id])
      @pipeline.void_new_jobs
      respond_to do |format|
        format.html { 
          flash[:notice] = "Pipeline: New jobs set to Void ..."
          redirect_to pipeline_path(@pipeline) 
        }
        # format.xml { render :xml => @pipeline.to_xml(:include => {:tasks =>{:only =>[:id]}}) }
      end
    rescue Exception => e
      logger.debug("void_new_jobs: problem getting jobs for pipeline #{pipeline_id} #{e.inspect}  ...")
      respond_to do |format|
        format.html { 
          flash[:error] = "void_new_jobs: problem getting jobs for pipeline #{pipeline_id}"
          redirect_to pipeline_path(@pipeline) 
        }
        # format.xml { render :xml => @pipeline.to_xml(:include => {:tasks =>{:only =>[:id]}}) }
      end
    end
  end

  def get
    @pipeline = Pipeline.new
    @pipeline.user_id = @authn_user.id
    @pipeline.state_id = PipelineState.where(name: 'initializing').first.id
    @pipeline             # need to return a pipeline
  end

  def new
    @pipeline = Pipeline.new
    @pipeline.user_id = @authn_user.id
    @pipeline.state_id = PipelineState.where(name: 'initializing').first.id
    @states = PipelineState.where(status: 1)
    @pipeline             # need to return a pipeline
  end

  def create
    #@pipeline = Pipeline.new(params[:pipeline])
	#"pipeline"=>{"name"=>":ben:new_pipeline", "pipe_root"=>"new_pipeline", "data_root"=>"data", "software_root"=>"https://svn.astro.washington.edu/admin/svn/astro/pipe_3.0", "shared_secret"=>"foo", "configuration_root"=>"configuration"}
	@pipeline = Pipeline.create() do |p|
		p.name = params[:pipeline][:name]
		p.pipe_root = params[:pipeline][:pipe_root]
		p.data_root = params[:pipeline][:data_root]
		p.software_root = params[:pipeline][:software_root]
		p.shared_secret = params[:pipeline][:shared_secret]
		p.configuration_root = params[:pipeline][:configuration_root]
	end

    if (@authn_user.nil? && !params[:user].nil?)
        @authn_user = User.find_by_name(params[:user])
    end

    @pipeline.user_id = (@authn_user.nil?) ? 0 : @authn_user.id
    @pipeline.bucket = "uw-astro-pipelines"
    @pipeline.state_id = PipelineState.where(name: 'initializing').first.id
    @pipeline.save!  # to get the pipeline.id ....

    # create ssh key
    comment = "u_#{@pipeline.user_id}-p_#{@pipeline.id}" # part of filename - keep filesystem friendly
    key_file_name ="ssh_key-#{comment}"
    ssh_key_file_name = @pipeline.ensure_crypto_dir + "/"+ key_file_name
    ssh_key_gen(ssh_key_file_name, comment, { :force => 1} );
    @pipeline.user_key_file_name = key_file_name # NOTE - no path
    @pipeline.container_root = "u_#{@pipeline.user_id}-p_#{@pipeline.id}-g_#{@pipeline.guid}"

    state_ready = PipelineState.find_by_name 'ready'
    @pipeline.state_id = state_ready.id
    @pipeline.save!
    # Every new pipeline gets a special task called the StartTask
    # This task has no software associated with it but it is capable of
    # generating "start" events.
    #task = @pipeline.tasks.build(:name => "StartTask", :flags =>"")
	task = @pipeline.tasks.build
	task.name = "StartTask"
	task.flags = ""
    task.save!
    
    respond_to do |format|
      format.html { redirect_to pipeline_path(@pipeline) }
      format.xml { render :xml => @pipeline.to_xml(:include => {:tasks =>{:only =>[:id]}}) }
    end

#    rescue ActiveRecord::RecordInvalid
#    respond_to do |format|
#      format.html { render :action => 'new' }
#      format.xml  { render :xml => @pipeline.errors.to_xml, :status => 500 }
#    end
  end

  def edit
    @pipeline = Pipeline.find(params[:id])
    # logger.debug("pipeline=#{@pipeline.inspect}")
    @states = PipelineState.where(status: 1, name: ['ready', 'hold'])
  end

  def update
    @pipeline = Pipeline.find(params[:id])
    @pipeline.attributes = params[:pipeline]
    @pipeline.state_id = params[:state_id]
    @pipeline.save!

    respond_to do |format|
      format.html { redirect_to pipeline_path(@pipeline) }
      format.xml { render :xml => @pipeline.to_xml, :status => :ok }
    end

    rescue ActiveRecord::RecordInvalid
    
    respond_to do |format|
      format.html { render :action => 'edit' }
      format.xml { render :xml => @pipeline.errors.to_xml, :status => 500 }
    end
  end

  def destroy
    @pipeline = Pipeline.find(params[:id])
    state_shuttingdown = PipelineState.find_by_name 'shuttingdown'
    @pipeline.state_id = state_shuttingdown.id
    @pipeline.save!
    @pipeline.destroy
    respond_to do |format|
      format.html { redirect_to pipelines_path }
      format.xml { head :ok }
    end
  end

  #
  # Signal the pipeline that the user would like to refresh the software
  # tree.  Time to go to all of the nodes and trigger the subversion update.
  #
  def refresh
    @pipeline = Pipeline.find(params[:id])
    # logger.debug("pipeline refresh =#{@pipeline.inspect}")
    @pipeline.refresh
    respond_to do |format|
      format.html { 
        flash[:notice] = "Pipeline refreshing ..."
        redirect_to pipeline_path(@pipeline) 
      }
      format.xml { render :xml => @pipeline.to_xml, :status => :ok }
    end

    rescue 
      respond_to do |format|
        format.html { 
          flash[:error] = "Error: "
          redirect_to pipeline_path(@pipeline) 
        }
        format.xml { render :xml => @pipeline.errors.to_xml, :status => 500 }
    end
  end

  #
  # requires a target and a configuration, as well as the name of the task
  # to be started
  def startJob
    @pipeline  = Pipeline.find(params[:id])
    @target    = Target.find(params[:target_id])
    @config    = ::Configuration.find(params[:configuration_id])
    @startname = params[:startname]
  end

  # NOTE: all signature stuff is now generalized and in authenticate before filter
  def get_aws_credentials
    pipeline_id  = params[:pipeline_id]
    ec2_instance_id  = params[:ec2_instance_id]

     
    @pipeline = Pipeline.find(pipeline_id);
	puts "pipeline: find #{@pipeline.inspect}"
	logger.info( "pipeline: find #{@pipeline.inspect}")
    # logger.debug( "pipeline=#{@pipeline.inspect}")

    @credentials = ec2_get_crypto_assets_for_user @pipeline.user_id

    # logger.info( "creds=#{@credentials.inspect}")
	puts "creds=#{@credentials.inspect}"   
 
    respond_to do |format|
      format.xml { render :xml => @credentials.to_xml, :status => 200 }
      format.json { render :json => @credentials.to_json, :status => 200 }
    end
  end


  # fetches a data product from this pipeline
  # specified by its relative path
  #
  def dpbypath
    @pipeline = Pipeline.find(params[:id])
    @relpath  = params[:relpath]
    @sql = "SELECT data_products.* \
       FROM data_products, configurations, targets \
       WHERE data_products.relativepath = '#{@relpath}' \
       AND data_products.configuration_id = configurations.id \
       AND configurations.target_id = targets.id \
       AND targets.pipeline_id = #{@pipeline.id} LIMIT 1"

    #  logger.info(@sql)
    # puts @sql

    @dataproduct = DataProduct.find_by_sql(@sql)[0]

#    @dataproduct = DataProduct.find_by_sql("SELECT data_products.* \
#       FROM data_products, configurations, targets \
#       WHERE data_products.relativepath = #{@relpath} \
#       AND data_products.configuration_id = configurations.id \
#       AND configurations.target_id = targets.id \
#       AND targets.pipeline_id = #{@pipeline.id}")

#    respond_to do |format|
#      format.xml { render :xml => @dataproduct.to_xml, :status => :ok }
#    end if ( @dataproduct )

    unless @dataproduct.nil?
      respond_to do |format|
        format.xml { render :xml => @dataproduct.to_xml, :status => :ok }
        format.html { @dataproduct }
      end
    else
      respond_to do |format|
        format.xml { render :xml => "No such record", :status => :ok }
        format.html { redirect_to pipeline_path }
      end
    end
  end

  def update_state
    state_ready = PipelineState.find_by_name 'ready'
    state_hold = PipelineState.find_by_name 'hold'
    id = params[:id]
    state_id = params[:state_id]
    pipeline = Pipeline.find(id)
    pipeline.state_id = (state_id == state_ready.id) ? state_ready.id : state_hold.id
    pipeline.save!
    flash[:notice] = "Updated pipeline state"
    redirect_to pipeline_path
  end

  def update_statuses
    state_ready = PipelineState.find_by_name 'ready'
    state_hold = PipelineState.find_by_name 'hold'
    pipeline_hold_ids = params[:pipeline_hold_ids]
    pipeline_ready_ids = params[:pipeline_ready_ids]
    logger.debug("pipeline_hold_ids = #{pipeline_hold_ids.inspect}")
    logger.debug("pipeline_ready_ids = #{pipeline_ready_ids.inspect}")
    if (pipeline_hold_ids.nil? && pipeline_ready_ids.nil?)
      # set error message, bounce back to index ...
      flash[:error] = "No selected pipeline ?"
      redirect_to "/pipelines/"
      return 
    end
    # NOTE: could do this with on sql update, BUT we want to be able to do user auth validation, so loop ...
    # also, this is an infrequent call ...
    error_msg = nil
    if (!pipeline_hold_ids.nil?)
      pipeline_hold_ids.each do |pid|
        logger.debug("hold pid = #{pid.inspect}")
        pipeline = Pipeline.find(pid)
        logger.debug("pipeline = #{pipeline.inspect}")
        if (pipeline.nil?)
          error_msg += "Problem with pid #{pid}\n"
          next
        end
        if (@authn_user.is_admin || (@authn_user.id == pipeline.user_id ))
          pipeline.state_id = state_hold.id
          pipeline.save!
        else
          error_msg += "Not authorized to update pid #{pid}\n"
        end
      end
    end
    if (!pipeline_ready_ids.nil?)
      pipeline_ready_ids.each do |pid|
        logger.debug("ready pid = #{pid.inspect}")
        pipeline = Pipeline.find(pid)
        logger.debug("pipeline = #{pipeline.inspect}")
        if (pipeline.nil?)
          error_msg += "Problem with pid #{pid}\n"
          next
        end
        if (@authn_user.is_admin || (@authn_user.id == pipeline.user_id ))
          pipeline.state_id = state_ready.id
          pipeline.save!
        else
          error_msg += "Not authorized to update pid #{pid}\n"
        end
      end
    end
    flash[:notice] = "Updated Pipelines ..."
    redirect_to "/pipelines/"
  end

private
  def _find_event_by_id( pipeline_all_events, event_id)
    # logger.debug("event_id=#{event_id.inspect}")
    result = nil
    return result if pipeline_all_events.nil?
    pipeline_all_events.each do |event|
      if event.id == event_id
        result = event
        break
      end
    end
    # logger.debug("result=#{result.inspect}")
    return result
  end

  def _find_job_by_id( pipeline_all_jobs, job_id)
    # logger.debug("job_id=#{job_id.inspect}")
    result = nil
    return result if pipeline_all_jobs.nil?
    pipeline_all_jobs.each do |job|
      if job.id == job_id
        result = job
        break
      end
    end
    # logger.debug("result=#{result.inspect}")
    return result
  end

  def _find_task_by_id( pipeline_all_tasks, task_id)
    # # logger.debug("task_id=#{task_id.inspect}")
    result = nil
    return result if pipeline_all_tasks.nil?
    pipeline_all_tasks.each do |task|
      if task.id == task_id
        result = task
        break
      end
    end
    # # logger.debug("result=#{result.inspect}")
    return result
  end

  def _find_events_by_id(pipeline_all_events, event_id)
    # logger.debug("event_id=#{event_id.inspect}")
    result = nil
    return result if pipeline_all_events.nil?
    pipeline_all_events.each do |event|
      if event.id == event_id
        result = [] if result.nil?
        result.push event
      end
    end
    # logger.debug("result=#{result.inspect}")
    return result
  end

  def _find_events_by_job_id(pipeline_all_events, job_id)
    # logger.debug("job_id=#{job_id.inspect}")
    result = nil
    return result if pipeline_all_events.nil?
    pipeline_all_events.each do |event|
      if event.job_id == job_id
        result = [] if result.nil?
        result.push event
      end
    end
    # logger.debug("result=#{result.inspect}")
    return result
  end

  def _find_jobs_by_event_id(pipeline_all_jobs, event_id)
    # logger.debug("event_id=#{event_id.inspect}")
    result = nil
    return result if pipeline_all_jobs.nil?
    pipeline_all_jobs.each do |job|
      if job.event_id == event_id
        result = [] if result.nil?
        result.push job
      end
    end
    # logger.debug("result=#{result.inspect}")
    return result
  end

  def _find_jobs_by_id(pipeline_all_jobs, job_id)
    # logger.debug("job_id=#{job_id.inspect}")
    result = nil
    return result if pipeline_all_jobs.nil?
    pipeline_all_jobs.each do |job|
      if job.id == job_id
        result = [] if result.nil?
        result.push job
        break
      end
    end
    # logger.debug("result=#{result.inspect}")
    return result
  end

  def _render_pipeline_jobs_tree_branch(job, depth)
    if (job.nil?)
      logger.debug("job nil @ depth #{depth}")
      return nil
    end
    if (depth > MAX_RECURR_DEPTH)
      logger.debug("depth maxed at #{depth}")
      return nil
    end
    if (@visited_jobs.include?(job.id))
      logger.debug("already visited job #{job.inspect}")
      return nil
    end
    @visited_jobs.push job.id

    @pipeline_tree_tree += "<li id=\"job_#{job.id}\">\n";
    task = _find_task_by_id(@pipeline_all_tasks,job.task_id)
    task_name = (task.nil?) ? 'NO_TASK?' : task.name
    task_id = (task.nil?) ? 'NO_ID?' : task.id
    status_label=_get_label_from_job_state(job)
    job_node_label = ""
    #  NOTE: job.node does a lookup 
    if job.node.nil?
      job_node_label = "node #{job.node_id} deleted"
    else
      job_node_label = "node #{job.node_id} ip=#{job.node.network_addr_ext.inspect}"
    end
    @pipeline_tree_tree += "<a href=\"#\" onclick=\"showDetails('job',#{job.id}, '#{CGI.escapeHTML(job.to_json+'<p>'+job_node_label)}'); return false;\">Job(#{job.id}): #{status_label} (#{job_node_label}) : for Task(#{task_id}): #{task_name}</a>\n";
    events = _find_events_by_job_id(@pipeline_all_events,job.id)
    if ( events.nil?)
        logger.debug("no child events for job=#{job.inspect}")
        return nil
    else
      @pipeline_tree_tree += "<ul>\n";
      events.each do |event|
        if (@visited_events.include?(event.id))
          logger.debug("already visited event #{event.inspect}")
        else
          @pipeline_tree_tree += "<li id=\"event_#{event.id}\">\n";
          event_label = _get_label_from_event(event)
          @pipeline_tree_tree += "<a href=\"#\" onclick=\"showDetails('event',#{event.id}, '#{CGI.escapeHTML(event.to_json)}'); return false;\">Event(#{event.id}): #{event_label}</a>\n";
          @visited_events.push event.id
          child_jobs = _find_jobs_by_event_id(@pipeline_all_jobs,event.id)
          if ( child_jobs.nil?)
              # logger.debug("no child jobs for event=#{event.inspect}")
              # logger.debug("no child jobs for event=#{event.id}")
          else
            @pipeline_tree_tree += "<ul>\n";
            child_jobs.each do |child_job|
              ok = _render_pipeline_jobs_tree_branch(child_job, (depth+1))
            end
            @pipeline_tree_tree += "</ul>\n";
          end
          @pipeline_tree_tree += "</li>\n";
        end
      end
      @pipeline_tree_tree += "</ul>\n";
    end
    @pipeline_tree_tree += "</li>\n";
  end

  def _get_label_from_event(event)
    label = 'NIL'
    case  event.name
      when'completed'
        label = "<font color='green'>completed</font>" 
      when'failed'
        label = "<font color='red'>FAILED</font>" 
      when'start'
        label = "<font color='blue'>start</font>" 
      else
        label = "<font color='cyan'>#{event.name.inspect}</font>" 
    end
    return label
  end

  def _get_label_from_job_state(job)
    status_label = 'NIL'
    case  job.state
      when'completed'
        status_label = "<font color='green'>completed</font>" 
      when'failed'
        status_label = "<font color='red'>FAILED</font>" 
      when'launched'
        status_label = "<font color='blue'>launched</font>" 
      when'starting'
        status_label = "<font color='#AABBCC'>starting</font>" 
      when'void'
        status_label = "<font color='#66666'>VOID</font>" 
      when'new'
        status_label = "<font color='#660066'>new</font>" 
      else
        status_label = "<font color='cyan'>#{job.state.inspect}</font>" 
    end
    return status_label
  end

end


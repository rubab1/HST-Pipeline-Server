# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base


  helper :all # include all helpers, all the time
  # protect_from_forgery # See ActionController::RequestForgeryProtection for details


  MAX_TS_DELTA=3*60*60 # 3 hours

  RELAX_API_AUTH=false

# ==============================================================================
  def perform_action
    # use session_id if possible ...
    @request_guid = (session.nil? || session[:session_id].nil?) ? @request_guid : 'si-'+session[:session_id]
    logger.prefix = @request_guid
    logger.debug{"#{@method_name} : start ... "}
    logger.debug{"#{@method_name} : params : #{params.inspect}"} #TODO: this does not filter passwords etc !!!
    logger.debug{"#{@method_name} : session : #{session.inspect}"}
    super
    logger.debug{"#{@method_name} : end."}
  end

# ==============================================================================

  private
  def authenticate
    authed = false
    respond_to do |format|
     format.xml { 
      # logger.debug("authN for xml...")
      has_valid_signature
      authed = true
     }
     format.json { 
      # logger.debug("authN for json...")
      has_valid_signature
      authed = true
     }
     format.html { 
      # NOTE: this needs to be here, or we lose the format down stream
      # logger.debug("authN for html...")
      authed = false # catch below in the fall thru case ...
     }
    end
    if !authed 
      # logger.debug("authN fall thru , assuming HTML ...") # assume html if not supported format
      # do they have a valid session ?
      @authn_user_guid = session[:rpipeline_user_guid] # NOTE: this could be spoofed, we could sign this if we really care
      if @authn_user_guid.blank?
        redirect_to :controller => 'users', :action => 'login'
        return false # stop the filter process
      else
        @authn_user = User.find_by_guid(@authn_user_guid)
        # logger.debug("authz_is_admin: logged in user = #{@authn_user.inspect}")
        if @authn_user.blank?
          redirect_to :controller => 'users', :action => 'login'
          return false # stop the filter process
        end
      end
    end
  end

  def authz_is_admin
    is_ok = false
    if @authn_user.blank?
      if @authn_user_guid.blank?
        @authn_user_guid = session[:rpipeline_user_guid]
        # logger.debug("authz_is_admin: logged in @authn_user_guid = #{@authn_user_guid.inspect}")
        if !@authn_user_guid.blank?
          @authn_user = User.find_by_guid(@authn_user_guid)
        end
      end
    end
    # logger.debug("authz_is_admin: logged in user = #{@authn_user.inspect}")
    is_ok = true if @authn_user && @authn_user.is_admin
    if ! is_ok
      logger.warn("authz_is_admin: unauhtorized access for user = #{@authn_user.inspect}")
      flash[:error] = "Unauthorized access"
      redirect_to '/users/'
      return false # stop the filter process
    end
    return true
  end


    # ----------------------------------------------------------------------------------

    def has_valid_timestamp( passed_ts )
      ts = Time.now.to_i 
      ts_delta = ts - passed_ts 
      if ( ts_delta > MAX_TS_DELTA ) 
        # TURNED OFF FOR DEBUGGGING
        # logger.info("Signature too old : ours=#{ts} , passed=#{passed_ts}, delta=#{ts_delta}")
        # return false # stop the filter process
        return true
      else
        return true
      end
    end

    def has_valid_signature
      passed_ts = params[:ts].to_i
      # special case logic for bootstrapping:
      if (params[:controller] == "pipelines" )
        if ((params[:action] == 'create') || (params[:action] == "new" ) || (params[:action] == "checkout" ))
          logger.warn("has_valid_signature: SPECIAL CASE: allowing #{params[:controller]} : #{params[:action]}")
          # set @authn_user ... ???
          return true
        end
      end

      begin
        # see if it is too old
        if ( !has_valid_timestamp(passed_ts) ) 
          logger.warn("has_valid_signature: Signature too old")
          if !RELAX_API_AUTH 
            head :bad_request
            return false # stop the filter process
          end
        end
        passed_signature=params[:sig]
        passed_pipeline_id=params[:pipeline_id]

        secret = Pipeline.get_shared_secret_by_id passed_pipeline_id
        signed_params = {
            :ts => passed_ts,
            :pipeline_id => passed_pipeline_id
          }
		logger.info("Signed params = #{signed_params.inspect}")
        our_signature = signature_for( secret, signed_params )
        if ( our_signature != passed_signature ) 
          logger.info("Signature mismatch : ours=#{our_signature} , passed=#{passed_signature}")
          if !RELAX_API_AUTH 
            head :bad_request
            return false # stop the filter process
          end
        end
        # setup @authn  params for downstream use
        @pipeline = Pipeline.find(passed_pipeline_id);
        # logger.debug("has_valid_signature: pipeline = #{@pipeline.inspect}")
        @authn_user = User.find(@pipeline.user_id)
        # logger.debug("has_valid_signature: logged in user = #{@authn_user.inspect}")
        if @authn_user.blank?
          head :bad_request
          return false # stop the filter process
        end
        @authn_user_guid = @authn_user.guid
      rescue Exception => e
        logger.info("Exception on signature validation : #{e.inspect}")
        head :bad_request
        return false # stop the filter process
      end
      return true
    end

  # ----------------------------------------------------------------------------------

  def signature_for( secret, signed_params )
    hash_to_sign = signed_params.select{|k,v| !v.blank? }  # filter out empty params
    # logger.info "HASH TO SIGN Signing #{hash_to_sign.inspect} "
    to_sign = hash_to_sign.collect{|tuple| tuple.first}.collect{|k| k.to_s}.sort. # sort the keys
      collect{ |k| k + signed_params[k.to_sym].to_s }.join('') # create canonical string
    # logger.info "TO SIGN Signing #{to_sign.inspect} "
    signature = Digest::MD5.hexdigest( to_sign + secret ) #TODO: synchonize under heavy load ?
  end


  # ----------------------------------------------------------------------------------

    
# ==============================================================================

end

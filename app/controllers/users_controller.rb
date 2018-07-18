class UsersController < ApplicationController

  include Ec2Helper

  before_action :authenticate, :except => [ :login ]
  before_action :authz_is_admin, :only => [ :new, :create, :destroy ]

  layout 'users'

  def index
    if @authn_user.is_admin
      @users = User.all.order('name ASC')
    end
    respond_to do |format|
      format.xml { render :xml => @authn_user.to_xml }
      format.json { render :json => @authn_user.to_json }
      format.html { }
    end
  end

  def login
    @user = nil
    # if already logged in, get user object
    @authn_user_guid = session[:rpipeline_user_guid]
    logger.debug("login: authn_user_guid = #{@authn_user_guid.inspect}")

    if ! @authn_user_guid.blank?
      redirect_to :action => 'index' 
      return
    end

    form_user = params[:user]
    if form_user.blank?
				puts "Missing params..."
        # flash[:error] = "Missing params"
    else
      user_name = form_user[:name]
      user_password = form_user[:password]
      logger.debug("login: user name= #{user_name.inspect}")
  
      if (!user_name.blank? && !user_password.blank?) 
        @authn_user = User.is_valid_login(user_name, user_password)
        logger.debug("login: is valid user = #{@authn_user.inspect}")
        if @authn_user.nil?
          flash[:error] = "Invalid Login"
        else 
          # set session
          session[:rpipeline_user_guid] = @authn_user.guid # TODO: set timeout
          # redirect_to :action => 'index' 
          flash[:notice] = "User #{@authn_user.name} Logged In"
          redirect_to '/'
          return
        end
      end
    end
  end

  def logout
    logger.debug("logout: ")
    session[:rpipeline_user_guid] = nil
    redirect_to :action => 'login' 
    return
  end

  def update
    logger.debug("users update: ")
    return if !authz_is_admin
    # NOTE: might not be updated authn_user
    user_id = params[:id]
    logger.debug("users update: user_id #{user_id}")
    @user = User.find_by_id(user_id)
    logger.debug("update: user = #{@user.inspect}")
    if @user.nil?
      flash[:error] = "Invalid User!!!"
      redirect_to :action => 'index' 
    end 
  end

  def do_update
    logger.debug("users do_update: ")
    form_user = params[:user]
    admin_update = params[:admin_update]
    if form_user.blank?
        flash[:error] = "missing params"
    else
      user_guid = form_user[:guid]
      user_password = form_user[:password]
      user_email = form_user[:email]
      user_name = form_user[:name]
      user_is_admin = form_user[:is_admin]

      #todo: validate that user is admin 
      if user_guid != @authn_user.guid
        if !authz_is_admin
          logger.info("do_update: non admin can't edit others}")
          return
        end
      end
      logger.debug("do_update: user_guid = #{user_guid}")
      @user = User.find_by_guid(user_guid)
      logger.debug("do_update: user = #{@user.inspect}")
      if @user.nil?
        flash[:error] = "invalid user!!!"
      else 
        changed = false
        if !user_password.blank?
          @user.set_password(user_password)
          changed = true
        end
        if !user_email.blank?
          @user.email = user_email
          changed = true
        end
        if !user_name.blank?
          @user.name = user_name
          changed = true
        end

        # hacky
        if (!admin_update.blank?)
          @user.is_admin = (user_is_admin == 'on' ) ? true : false
          changed = true
        end

        if changed
          @user.save! 
          flash[:notice] = "user info updated"
        end
      end
    end
    redirect_to :action => 'index' 
  end

  def new
    @user = nil
  end

  def create
    logger.debug("users create: ")
    form_user = params[:user]
    if form_user.blank?
        flash[:error] = "missing params"
        redirect_to :action => 'new' 
        return
    end
    user_name = form_user[:name]
    user_password = form_user[:password]
    user_email = form_user[:email]
    user_name = form_user[:name]
    user_is_admin = form_user[:is_admin]

    err_msg = ''
    err_msg += "Missing User Name\n" if user_name.blank?
    err_msg += "Missing User Password\n" if user_password.blank?
    if !err_msg.blank?
        flash[:error] = err_msg
        redirect_to :action => 'new' 
        return
    end

    @user = User.create
    @user.name = user_name
    @user.email = user_email
    @user.set_password(user_password)
    @user.is_admin = (user_is_admin == 'on' ) ? true : false

    @user.save! 
    logger.debug("new user : #{@user.inspect} ")
    flash[:notice] = "User #{@user.name} created"
    redirect_to :action => 'index' 
  end

  def destroy
    user_id = params[:id]
    if (user_id.blank?)
      flash[:error] = "Missing User ID"
      return
    end
    @user = User.find(user_id)
    ok = @user.destroy
    if (ok) 
      flash[:notice] = "User #{@user.name} deleted"
    else
      flash[:error] = "Problem deleting User id #{user_id} "
    end
    redirect_to :action => 'index' 
  end

end

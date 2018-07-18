# ====================================================================================
#  encapsulate stuff that Net::ssh doesn't provide ...
# ====================================================================================
module SshHelper

  require 'net/scp'
  include Ec2Helper
  SERVER_DATA  = YAML.load_file("#{Rails.root}/config/pipeline-server.yml")[Rails.env]
  # ----------------------------------------------------------------------------------

  def ssh_key_gen(output_file_name, comment, options={})
    if File.exist?( output_file_name ) 
      if options[:force] 
        # try to remove it - and the .pub version
        system("rm -f #{output_file_name}* ")
      else
        raise "Key file already exists: #{output_file_name}"
      end
    end
    begin
      # TODO: test if output_file_name is writeable 
      clean_comment = _sanitize_filename comment 
      # check to see if file already exists
      logger.debug("command: ssh-keygen -f \"#{output_file_name}\" -t rsa -C \"#{clean_comment}\"  -N \"\"")
      system("ssh-keygen -f \"#{output_file_name}\" -t rsa -C \"#{clean_comment}\"  -N \"\" ")
      exit_code = $?
      logger.debug("ssh-keygen command exit code = #{exit_code}")
      raise "Problem creating key, exit code = #{exit_code}" unless exit_code == 0
      # TODO: is this right ?
      FileUtils.chmod( 0600, output_file_name )
      FileUtils.chmod( 0664, output_file_name+".pub" )
    rescue Exception => e
      logger.debug("ssh_key_gen: error creating #{output_file_name} = #{e}")
      #TODO: what to really do ?
      raise e
    end
  end

  # ----------------------------------------------------------------------------------
  # NOTE:  current AMI puser's authorized keys file has padmin@pipeline1 in it, so it could be used instead of ec2 root key ...
  def node_install_ssh_key(remote_server_addr, ssh_login_key_file, ssh_key_file_to_install, run_dir, options={})
    begin
      raise "Bad remote_server_addr" if remote_server_addr.blank?

      remote_server_user= ( options[:remote_ssh_user].nil? ) ? 'root'  :  options[:remote_ssh_user]
      dest_dir= ( options[:dest_dir].nil? ) ? '/home/puser/.ssh/'  :  options[:dest_dir]
      task_launch = ( options[:task_launch ].nil? ) ? '/opt/local/bin/taskLaunch'  :  options[:task_launch ]
      logger.debug("node_install_ssh_key : remote_server_addr=#{remote_server_addr} ssh_key_file_to_install=#{ssh_key_file_to_install}  dest_dir=#{dest_dir} ssh_login_key_file = #{ssh_login_key_file} ")

      # update authorized_keys file

      ssh_key_pub = File.open(ssh_key_file_to_install+".pub").read.strip

      dest_file = dest_dir+"/authorized_keys"
      # cmd = "command=\"cd #{run_dir} && #{task_launch} $SSH_ORIGINAL_COMMAND & \",no-pty,no-port-forwarding  #{ssh_key_pub}"
      # "bash -c 'cd /sci/data01/node_pipelines/users/3/pipelines/85/pipe1 && /opt/local/bin/taskLaunch $SSH_ORIGINAL_COMMAND' < /dev/null >> /var/tmp/tl.log 2>&1 &"
      cmd = "echo \"command=\\\"export JLOG=#{run_dir}/log/log4j.properties; bash -c 'cd #{run_dir} && #{task_launch} \\\$SSH_ORIGINAL_COMMAND ' < /dev/null >> /var/tmp/astro-taskLaunch.log 2>&1 & \\\",no-pty,no-port-forwarding  #{ssh_key_pub}\" >> #{dest_file}"
	puts "INSTALL SSH KEY COMMAND: #{cmd}"
      Net::SSH.start( remote_server_addr, remote_server_user,
           :host_key => "ssh-rsa",
           :encryption => "blowfish-cbc",
           :keys=> [ ssh_login_key_file],
           :verbose => :warn #:info # :debug
        ) do |ssh_session|
          # NOTE: depends on file existing, and having chmod 600 ... which is in AMI
          # TODO: pre or post pend to authorized_keys file ?
          result = _do_ssh_work(ssh_session, cmd)
          logger.debug("node_install_ssh_key : key add output = #{result.inspect}")
      end

    rescue Exception => e
      logger.debug("node_install_ssh_key: error installing ssh key = #{e.inspect}")
      #TODO: what to really do ?
      raise e
    end
  end
  # ----------------------------------------------------------------------------------
  def node_run_cts (remote_server_addr, ssh_login_key_file,  options={})
    begin
      raise "Bad remote_server_addr" if remote_server_addr.blank?
      remote_server_user= ( options[:remote_ssh_user].nil? ) ? 'root'  :  options[:remote_ssh_user]
      logger.debug("node_run_cts : remote_server_addr=#{remote_server_addr} ssh_login_key_file = #{ssh_login_key_file} ")

      result = nil
      Net::SSH.start( remote_server_addr, remote_server_user,
           :host_key => "ssh-rsa",
           :encryption => "blowfish-cbc",
           :keys=> [ ssh_login_key_file],
           :verbose => :warn #:info # :debug
        ) do |ssh_session|
          result = _do_ssh_work(ssh_session, "bash -c 'touch /UW_ASTRO_NODE_CTS  && /etc/astro-node-configure -d 2>&1 | tee -a /var/tmp/astro-node-configure.log '")
          logger.debug("node_run_cts : ssh output = #{result.inspect}")
      end

    rescue Exception => e
      logger.debug("node_run_cts: error running cts = #{e.inspect}")
      #TODO: what to really do ?
      raise e
    end
  end

  #
  # ----------------------------------------------------------------------------------
  def node_ensure_pipeline_dir (remote_server_addr, ssh_login_key_file,  root_dir, options={})
    begin
      raise "Bad remote_server_addr" if remote_server_addr.blank?
      remote_server_user= ( options[:remote_ssh_user].nil? ) ? 'root'  :  options[:remote_ssh_user]
      remote_dir_user= ( options[:remote_dir_user].nil? ) ? 'puser'  :  options[:remote_dir_user]
      logger.debug("node_ensure_pipeline_dir : remote_server_addr=#{remote_server_addr} root_dir=#{root_dir} ssh_login_key_file = #{ssh_login_key_file} ")

      result = nil
      Net::SSH.start( remote_server_addr, remote_server_user,
           :host_key => "ssh-rsa",
           :encryption => "blowfish-cbc",
           :keys=> [ ssh_login_key_file],
           :verbose => :warn #:info # :debug
        ) do |ssh_session|
          # NOTE: depends on file existing, and having chmod 600 ... which is in AMI
          # TODO: pre or post pend to authorized_keys file ?
          cmd="mkdir -p \"#{root_dir}\" && chown #{remote_dir_user}:#{remote_dir_user} #{root_dir} && chmod 777 #{root_dir}"
          logger.debug("node_ensure_pipeline_dir : cmd = #{cmd.inspect}")
          result = _do_ssh_work(ssh_session, cmd)
          logger.debug("node_ensure_pipeline_dir : mkdir piperoot ssh output = #{result.inspect}")
          # ln -s /sci/data01/node_pipelines/users/3/pipelines/78 /home/puser/
          cmd="rm -f /home/#{remote_dir_user}/pipe_dir && ln -s \"#{root_dir}\" /home/#{remote_dir_user}/pipe_dir"

          logger.debug("node_ensure_pipeline_dir : cmd = #{cmd.inspect}")
          result = _do_ssh_work(ssh_session, cmd)
          logger.debug("node_ensure_pipeline_dir : ln -s ssh output = #{result.inspect}")
      end

    rescue Exception => e
      logger.debug("node_ensure_pipeline_dir: error ensuring  pipeline dir = #{e.inspect}")
      #TODO: what to really do ?
      raise e
    end
  end

  # ----------------------------------------------------------------------------------
  # TODO: should this be in the node model or ???
  def node_ssh_cpipe_command ( node, cmd, options= {})
    begin
      remote_server_addr = node.get_prefered_network_address
      pipeline = Pipeline.find(node.pipeline_id)
      ssh_login_key_file= pipeline.get_root_key_filename!
      remote_server_user = 'puser' #TODO get from options
      #server_url = "http://pipeline1.astro.washington.edu"  #TODO get from options
	  server_url = SERVER_DATA['server_address'] 
      puts "USER id = #{node.user_id}, SERVER addr = #{server_url}"
      login_user = 'root'
      root_dir = pipeline.get_node_pipe_root
      shared_secret = pipeline.shared_secret
      result = nil
      Net::SSH.start( remote_server_addr, login_user,
           :host_key => "ssh-rsa",
           :encryption => "blowfish-cbc",
           :keys=> [ ssh_login_key_file],
           :verbose => :warn #:info # :debug
        ) do |ssh_session|
          # result = _do_ssh_work(ssh_session, "su #{remote_server_user} -c \"cd  '#{root_dir}' &&  /opt/local/bin/cpipe -pid #{pipeline.id} -url '#{server_url}' -sss '#{shared_secret}' #{cmd} 2>&1 | tee -a /var/tmp/astro-cpipe-commands.#{pipeline.id}.log\"")
          result = _do_ssh_work(ssh_session, "su #{remote_server_user} -c \"cd  '#{root_dir}' &&  /opt/local/bin/cpipe -pid #{pipeline.id} -url '#{server_url}' -sss '#{shared_secret}' #{cmd} \"")
          #logger.debug(
		  puts "node_ssh_cpipe_command: su #{remote_server_user} -c \"cd  '#{root_dir}' &&  /opt/local/bin/cpipe -pid #{pipeline.id} -url '#{server_url}' -sss '#{shared_secret}' #{cmd}\"   ===> #{result.inspect}"
      end
    rescue Exception => e
      logger.debug("node_ssh_cpipe_command: error #{e.inspect}")
      #TODO: what to really do ?
      raise e
    end
    return result
  end

  # ----------------------------------------------------------------------------------
  #
  # Call a special restricted key access on the actual node by inserting this
  # in the authorized_keys file
  #
  # command="cd /Users/rosema/tmp/pipe && /Users/rosema/bin/taskLaunch -job $SSH_ORIGINAL_COMMAND",no-pty,no-port-forwarding  ssh-r saAAA-BIG-LONG-KEY-HERE-Q== rosema@Milano.local
  #             ^^^^^^^^^^^^^^^^^^^^^^            ^^^^^^^^^^^^^^^^^^^^        ^^^^^^^^^^^^^^^^^^
  #             Root of pipeline activity         location of taskLaunch        job.id              safety stuff 
  #
  # "ssh -i #{pipeline_server_key_file_for_node} puser@#{node_addr}  #{job.id} &"
  #
  def node_ssh_run_job ( node, job, options= {})
    begin
      remote_server_addr = node.get_prefered_network_address
      pipeline = Pipeline.find(node.pipeline_id)
      ssh_login_key_file= pipeline.get_server_user_key_file
      login_user = 'puser' # TODO: check options ?
      result = nil
      Net::SSH.start( remote_server_addr, login_user,
           :host_key => "ssh-rsa",
           :encryption => "blowfish-cbc",
           :keys=> [ ssh_login_key_file],
           # :verbose => :warn #:info # :debug
           :verbose => :info 
        ) do |ssh_session|
          # result = _do_ssh_work(ssh_session, "#{job.id} &")
          result = _do_ssh_work(ssh_session, "#{job.id}")
          logger.debug("node_ssh_run_job: #{job.id}  ===> #{result.inspect}")
      end
    rescue Exception => e
      logger.debug("node_ssh_run_job: error #{e.inspect}")
      #TODO: what to really do ?
      raise e
    end
    return result
  end

  # ----------------------------------------------------------------------------------

  protected
  def _sanitize_filename ( filename, options= {} )
    # returning filename.downcase.strip do |name|
    #returning filename.strip do |name|
	filename.strip do |name|
      # # NOTE: File.basename doesn't work right with Windows paths on Unix
      # # get only the album_name, not the whole path
      name.gsub! /(\\)/, '' if options[:no_dirs]
      name.gsub! /(\/)/, '_' if options[:no_dirs]

      # # Finally, replace all non alphanumeric, underscore 
      # # or periods with underscore
      # # name.gsub! /[^\w\.\-]/, '_'
      # # Basically strip out the non-ascii alphabets too 
      # # and replace with x. 
      # # You don't want all _ :)
      name.gsub!(/[^0-9A-Za-z.\-]/, '_')
      name.gsub!(/\_+/,'_') # ditch multiple underscores
      name.gsub!(/\_$/,'')  # ditch trailing underscores
      name.gsub!(/^\_/,'')  # ditch leading underscores
    end
	return filename
  end

  def _do_ssh_work ( ssh_session, command )
    logger.debug("_do_ssh_work: begin ...  commnd=#{command.dump}")
	puts "my _do_ssh_work: begin .. command = #{command.dump}"
    result = {}
    result[:exit_code] = -1
    result[:std_out] = nil
    result[:std_err] = nil
    result[:msg] = nil
    ssh_session.open_channel do |channel|
      channel.exec(command) do |ch, success|
        unless success
        msg = "FAILED: couldn't execute command (ssh.channel.exec failure)"
        result[:msg] = msg
        logger.info("_do_ssh_work: #{msg}")
        return result
      end
      channel.on_data do |ch, data|  # stdout
        result[:std_out] = ''  if result[:std_out].nil?
        result[:std_out] += data
        logger.info("_do_ssh_work: std_out +=  : #{data}")
      end
      channel.on_extended_data do |ch, type, data|
        next unless type == 1  # only handle stderr
        result[:std_err] = ''  if result[:std_err].nil?
        result[:std_err] += data
        logger.info("_do_ssh_work: std_err +=  : #{data}")
      end
      channel.on_request("exit-status") do |ch, data|
        exit_code = data.read_long
		puts "_channel on_request exit code = #{exit_code}"
        result[:exit_code] = exit_code
        if exit_code != 0
          logger.info("_do_ssh_work: non-zero exit code : #{exit_code}")
        end
      end
      channel.on_request("exit-signal") do |ch, data|
        msg = "SIGNAL: #{data.read_long}"
        result[:msg] = msg
        logger.info("_do_ssh_work: SIGNAL: #{msg}")
        end
      end
    end
    ssh_session.loop
    logger.debug("_do_ssh_work: end ...  result=#{result.inspect}")
    return result
  end

end

# ====================================================================================
# EOF
# ====================================================================================


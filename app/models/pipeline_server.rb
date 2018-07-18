class PipelineServer < ActiveRecord::Base

  require 'fileutils'
  include Ec2Helper

  SERVER_DATA  = YAML.load_file("#{Rails.root}/config/pipeline-server.yml")[Rails.env]
  EC2_CRYPTO_DATA  = YAML.load_file("#{Rails.root}/config/ec2-crypto.yml")[Rails.env]

  def PipelineServer.process_pipeline_queue(parent_process_name, owner_name, pid=nil)
    #puts "PipelineServer.process_queue"
    logger.info("PipelineServer.process_pipeline_queue: begin ...")
    state_ready = PipelineState.where(name: 'ready').first
    @pipelines = Pipeline.where(state_id: state_ready.id)
    return nil if @pipelines.nil?
    @pipelines.each do |pipeline|
      begin
        logger.info  "PipelineServer.process_pipeline_queue: processing #{pipeline.id} ..."
        pipeline.process_queue(parent_process_name, owner_name, pid=nil)
      rescue Exception => e
        logger.info("ERROR: problem processing queue for #{pipeline.inspect} => #{e.inspect}")
      end
    end
     logger.info("PipelineServer.process_pipeline_queue: end.")
  end

  def PipelineServer.node_crypto_base_dir
    return SERVER_DATA['node_crypto_base_dir']
  end

  def PipelineServer.get_node_tools_base_dir
    return SERVER_DATA['node_tools_base_dir']
  end

  def PipelineServer.get_crypto_dirname_for_pipeline(pipeline)
    base_dir = PipelineServer.node_crypto_base_dir
    crypto_dir = base_dir+"/users/#{pipeline.user_id}/pipelines/#{pipeline.id}"
  end

  def PipelineServer.ensure_crypto_dir_for_pipeline(pipeline,options={})
    dir = PipelineServer.get_crypto_dirname_for_pipeline(pipeline)
    logger.info("PipelineServer: ensuring crypto dir : #{dir.inspect} ...")
    #TODO test for existance ?
    FileUtils.mkdir_p(dir)
    FileUtils.chmod(0775,dir)
    return dir
  end

  def PipelineServer.get_server_user_key_file_for_pipeline(pipeline)
    crypto_dir = PipelineServer.get_crypto_dirname_for_pipeline(pipeline)
    file = pipeline.user_key_file_name
    key_file_name = crypto_dir+"/"+file
    # logger.info("PipelineServer: get_server_user_key_file_for_user_id : #{key_file_name.inspect} ...")
    return key_file_name
  end

  def PipelineServer.get_crypto_dirname_for_user_id(user_id)
    base_dir = PipelineServer.node_crypto_base_dir
    crypto_dir = base_dir+"/users/#{user_id}/keys/"
    return crypto_dir
  end

  def PipelineServer.ensure_crypto_dir_for_user_id(user_id,options={})
    crypto_dir = PipelineServer.get_crypto_dirname_for_user_id(user_id)
    logger.info("PipelineServer: ensuring crypto dir for user : #{crypto_dir.inspect} ...")
    #TODO test for existance ?
    FileUtils.mkdir_p(crypto_dir)
    FileUtils.chmod(0775,crypto_dir)
    return crypto_dir
  end

  def PipelineServer.get_root_key_filename_for_user_id(user_id,options={})
    crypto_dir = PipelineServer.get_crypto_dirname_for_user_id(user_id)
    user_obj = User.where(id: user_id).first
    user_name = user_obj.name
    creds = EC2_CRYPTO_DATA[user_name]
    pem_file = crypto_dir+"/#{creds['key_pair_name']}.pem"  #TODO: get this from ec2_helper ...
    #pem_file = crypto_dir+"/#{ec2_root_key_file_base_name(user_id)}.pem"
    #logger.info("Permission file name: #{pem_file}"
    return pem_file
  end

  def PipelineServer.get_root_key_filename_for_user_id!(user_id,options={})
    pem_file = PipelineServer.get_root_key_filename_for_user_id(user_id,options)
    raise "Missing root key file #{pem_file}" if ! File.readable?(pem_file)
    return pem_file
  end

end


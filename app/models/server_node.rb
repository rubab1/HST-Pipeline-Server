class ServerNode < ActiveRecord::Base
  has_many :pipelines, :class_name => "Pipeline"
  has_one :type, :class_name => "InstanceType"

  #attr_accessible :user_id, :type, :server_addr, :ec2_reservation_id, :ec2_root_key_name, :e2_instance_id, :pipeline_start, :pipeline_end, :status, :name

 def check_pipeline_overlap(pipeline_range)
  @active_servers = ServerNode.where(state: 'running')
  @active_servers.each do |s|
    if s.pipeline_end.to_i >= pipeline_range[0] or s.pipeline_start.to_i <= pipeline_range[1]
    else
      return false
    end
  end
  return true
 end

end

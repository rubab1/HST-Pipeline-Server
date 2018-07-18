class NodeType < ActiveRecord::Base
  # has_one :ec2_ami_types

  def self.get_id_for_localhost
    # HACK - should really look it up
    return 1
  end

  def self.get_by_name( name )
    return NodeType.where(name: name, status: 1).first
  end

  def self.get_active_node_types
    return NodeType.where(status: 1)
  end

  def self.get_active_ec2_node_types
    return NodeType.where(is_ec2_node: 1, status: 1)
  end

end

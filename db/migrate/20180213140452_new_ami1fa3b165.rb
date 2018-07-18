class NewAmi1fa3b165 < ActiveRecord::Migration[5.1]
  def self.up
    new_ami_name='ami-1fa3b165'

    new_ami = NodeType.create!(
      :is_ec2_node        => 1,
      :name               => 'ec2-General-Micro-ebs',
      :description        => 'general purpose 64bit micro EBS pipeline node',
      :ec2_ami_id         => new_ami_name,
      :ec2_instance_type  => 't1.micro',
      :has_memory_gb      => 0.6,
      :has_number_cpus    => 1,
      :has_local_storage  => false,
      :status             => 1
    )

    new_ami = NodeType.create!(
      :is_ec2_node        => 1,
      :name               => 'ec2-General-Large-ebs',
      :description        => 'general purpose 64bit EBS 15gb pipeline node',
      :ec2_ami_id         => new_ami_name,
      :ec2_instance_type  => 'm1.large',
      :has_memory_gb      => 7.5,
      :has_number_cpus    => 2,
      :has_local_storage  => true,
      :status             => 1
    )

    new_ami = NodeType.create!(
      :is_ec2_node        => 1,
      :name               => 'ec2-General-Xlarge-ebs',
      :description        => 'general purpose 64bit EBS 15gb pipeline node',
      :ec2_ami_id         => new_ami_name,
      :ec2_instance_type  => 'm1.xlarge',
      :has_memory_gb      => 15,
      :has_number_cpus    => 4,
      :has_local_storage  => true,
      :status             => 1
    )
    new_ami = NodeType.create!(
      :is_ec2_node        => 1,
      :name               => 'ec2-Hi-mem-Xlarge_16-ebs',
      :description        => 'general purpose 64bit EBS 16gb pipeline node',
      :ec2_ami_id         => new_ami_name,
      :ec2_instance_type  => 'm2.xlarge',
      :has_memory_gb      => 17.1,
      :has_number_cpus    => 2,
      :has_local_storage  => true,
      :status             => 1
    )
    new_ami = NodeType.create!(
      :is_ec2_node        => 1,
      :name               => 'ec2-Hi-mem-Xlarge_32-ebs',
      :description        => 'general purpose 64bit EBS 32gb pipeline node',
      :ec2_ami_id         => new_ami_name,
      :ec2_instance_type  => 'm2.2xlarge',
      :has_memory_gb      => 34.2,
      :has_number_cpus    => 4,
      :has_local_storage  => true,
      :status             => 1
    )
    new_ami = NodeType.create!(
      :is_ec2_node        => 1,
      :name               => 'ec2-Hi-mem-Xlarge_64-ebs',
      :description        => 'general purpose 64bit EBS 64gb pipeline node',
      :ec2_ami_id         => new_ami_name,
      :ec2_instance_type  => 'm2.4xlarge',
      :has_memory_gb      => 68.4,
      :has_number_cpus    => 8,
      :has_local_storage  => true,
      :status             => 1
    )

  end

  def self.down
    # can't go back - since this is related to external system state
    raise new ActiveRecord::IrreversibleMigration
  end
end

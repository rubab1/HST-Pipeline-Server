class TrueUpDbSeeding01 < ActiveRecord::Migration[5.1]
  def self.up

    # clear out node_types
    ActiveRecord::Base.connection.execute("TRUNCATE node_types") 
    # clear out node_states
    ActiveRecord::Base.connection.execute("TRUNCATE node_states") 

    local_node = NodeType.create!(
      :is_standalone_node => 1,
      :name               => 'localhost',
      :description        => 'localhost node - not for production',
      :status             => 1
    )

    #basic_ami = NodeType.create!(
    #  :is_ec2_node        => 1,
    #  :name               => 'ec2-general-large',
    #  :description        => 'general purpose 64bit pipeline node',
    #  :ec2_ami_id             => 'ami-32f4015b', # uw-astro-centos54-64-20100913a
    #  :ec2_instance_type  => 'm1.large',
    #  :status             => 1
    #)

   state = NodeState.create!(
         :name               => 'booting',
         :description        => 'OS is booting',
         :status             => 1
         )

   state = NodeState.create!(
         :name               => 'running',
         :description        => 'OS is booted, and has IP addresses',
         :status             => 1
         )
   state = NodeState.create!(
         :name               => 'updating',
         :description        => 'updating pipeline resources',
         :status             => 1
         )
   state = NodeState.create!(
         :name               => 'ready',
         :description        => 'ready for work, but no job yet',
         :status             => 1
         )
   state = NodeState.create!(
         :name               => 'hold',
         :description        => 'user has put node into a hold state',
         :status             => 1
         )
   state = NodeState.create!(
         :name               => 'pipeline_task',
         :description        => 'pipeline jobs are running',
         :status             => 1
         )
   state = NodeState.create!(
         :name               => 'idle',
         :description        => 'node can be re-used for another pipeline or terminated',
         :status             => 1
         )
   state = NodeState.create!(
         :name               => 'rebooting',
         :description        => 'node is rebooting',
         :status             => 1
         )
   state = NodeState.create!(
         :name               => 'shutting-down',
         :description        => 'OS is in processes of shutting down, can not be stopped',
         :status             => 1
         )
   state = NodeState.create!(
         :name               => 'terminated',
         :description        => 'instance is terminated',
         :status             => 1
         )

  end

  def self.down
    # no going back form this one either
  end
end




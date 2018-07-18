class SeedNodeStateTransitions < ActiveRecord::Migration[5.1]
  def self.up

   state = NodeState.create!(
         :name               => 'booting',
         :description        => 'we have an ec2 reservation_id and intance_id, but OS is still booting',
         :status             => 1
         )

   state = NodeState.create!(
         :name               => 'registered',
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
         :name               => 'running',
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
         :name               => 'shutting_down',
         :description        => 'OS is in processes of shutting down, can not be stopped',
         :status             => 1
         )
   state = NodeState.create!(
         :name               => 'terminated',
         :description        => 'instance is terminated',
         :status             => 1
         )
   state = NodeState.create!(
         :name               => 'stopped',
         :description        => 'node is stopped',
         :status             => 1
         )
   state = NodeState.create!(
         :name               => 'waiting',
         :description        => 'Waiting for Node allocation',
         :status             => 1
         )
  end

  def self.down
  end
end

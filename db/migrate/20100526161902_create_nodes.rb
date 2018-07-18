class CreateNodes < ActiveRecord::Migration[5.1]
  def self.up
    create_table :nodes do |t|
      t.integer :user_id, :null=>false
      t.integer :type_id
      t.string :name
      t.string :ec2_reservation_id, :limit=>64
      t.string :ec2_instance_id, :limit=>64
      t.string :ec2_root_key_name
      t.integer :state_id, :null=>false
      t.integer :desired_state_id
      t.string :region, :limit=>32
      t.string :agent
      t.references :pipeline
      t.string :status
      t.string :base_path
      t.string :network_addr_ext
      t.string :network_addr_int
      t.integer :last_job_id
      t.integer :num_jobs, :default => 0
      t.string :cost_model
      t.string :cost_base_price

      t.timestamps
    end
  end

  def self.down
    drop_table :nodes
  end
end

class BasicEc2MetaData < ActiveRecord::Migration[5.1]
  def self.up
    create_table :node_states do |t|
      t.string :name, :limit=>64, :null=>false
      t.string :description
      t.integer :status, :null=>false
      t.timestamps
    end
    add_index :node_states, :name, :unique => true

    create_table :node_types do |t|
      t.string :name, :limit=>64, :null=>false
      t.string :description
      t.string :ec2_ami_id, :limit=>64
      t.string :ec2_instance_type
      t.integer :status, :null=>false
      t.boolean :is_standalone_node, :default => 0
      t.boolean :is_ec2_node, :default => 0
      t.float :has_memory_gb, :default => 0.0
      t.integer :has_number_cpus, :default => 1
      t.boolean :has_local_storage, :default => 1
      t.timestamps
    end

    create_table :node_state_transitions do |t|
      t.integer :node_id, :null=>false
      t.string :description
      t.integer :from_state, :null=>false
      t.integer :to_state, :null=>false
      t.integer :user_id, :null=>false
      t.timestamps
    end

    create_table :ec2_user_creds do |t|
      t.integer :user_id, :null=>false
      t.string :cert_file
      t.string :key_file
      t.string :access_key
      t.string :access_secret
      t.timestamps
    end
  end

  def self.down
    remove_index :node_states, :name
    drop_table :node_types
    drop_table :node_states
    drop_table :ec2_user_creds
    drop_table :node_state_transitions
  end
end

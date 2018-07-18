class CreateServerNodes < ActiveRecord::Migration[5.1]
  def change
    create_table :server_nodes do |t|
      t.string :server_addr
      t.string :server_name
      t.string :ec2_reservation_id
      t.string :ec2_instance_id
      t.integer :type
      t.integer :user_id
      t.string :ec2_root_key_name
      t.integer :pipeline_start
      t.integer :pipeline_end
      t.string :status
      t.timestamps
    end
  end
  def up
   create_table :server_nodes do |t|
      t.string :server_addr
      t.string :server_name
      t.string :ec2_reservation_id
      t.string :ec2_instance_id
      t.string :ec2_root_key_name
      t.integer :type
      t.integer :user_id
      t.integer :pipeline_start
      t.integer :pipeline_end
      t.string :status
      t.timestamps
    end
   add_column :type, :string
   add_column :user_id, :integer
  end

end

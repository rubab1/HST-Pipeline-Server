class CreatePipelineProcessingLock < ActiveRecord::Migration[5.1]
  def self.up
    create_table :server_locks do |t|
      t.string :lock_name , :null=>false
      t.string :owner_name , :null=>false 
      t.string :process_name , :null=>false
      t.integer :pid
      t.timestamps
    end
    add_index :server_locks , :lock_name , :unique => true
  end

  def self.down
    drop_table :server_locks 
  end
end

class CreatePipelines < ActiveRecord::Migration[5.1]
  def self.up
    create_table :pipelines do |t|
      t.string :name
      t.string :software_root
      t.string :data_root
      t.string :configuration_root
      t.integer :lockcounter
      t.string :description
      t.string :pipe_root
      t.integer :user_id
      t.string :user_key_file_name
      t.string :guid
      t.string :container_root
      t.string :bucket
      t.string :shared_secret
      t.integer :state_id
      t.timestamps
    end
  end

  def self.down
    drop_table :pipelines
  end
end

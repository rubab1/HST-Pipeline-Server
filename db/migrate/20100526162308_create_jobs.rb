class CreateJobs < ActiveRecord::Migration[5.1]
  def self.up
    create_table :jobs do |t|
      t.string  :state
      t.integer :pid
      t.references :task
      t.references :configuration
      t.references :node
      t.bigint :event_id
      t.datetime :start_time
      t.datetime :end_time
      
      t.timestamps
    end
  end

  def self.down
    drop_table :jobs
  end
end

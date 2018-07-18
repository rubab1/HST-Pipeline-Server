class AddStatusToPipelines < ActiveRecord::Migration[5.1]
  def self.up
    create_table :pipeline_states do |t|
      t.string :name, :limit=>64, :null=>false
      t.string :description
      t.integer :status, :null=>false
      t.timestamps
    end
    add_index :pipeline_states, :name, :unique => true

    state = PipelineState.create!(
         :name               => 'initializing',
         :description        => 'preparing infrastucture for pipeline',
         :status             => 1
         )

    state = PipelineState.create!(
         :name               => 'ready',
         :description        => 'pipeline ready for jobs',
         :status             => 1
         )

    state = PipelineState.create!(
         :name               => 'hold',
         :description        => 'user has paused pipeline, no further jobs till ready again',
         :status             => 1
         )

    state = PipelineState.create!(
         :name               => 'shuttingdown',
         :description        => 'pipeline is shutting down, no further jobs',
         :status             => 1
         )

    ActiveRecord::Base.connection.execute("update pipelines set state_id=2")

  end

  def self.down
    remove_column :pipelines, :state_id
    drop_table :pipeline_states
  end

end

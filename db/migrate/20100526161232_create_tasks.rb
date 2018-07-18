class CreateTasks < ActiveRecord::Migration[5.1]
  def self.up
    create_table :tasks do |t|
      t.string :name
      t.string :flags
      t.references :pipeline
      t.integer :nruns
      t.integer :TotalRunTime
      t.boolean :is_exclusive, :default => false
      t.timestamps
    end
  end

  def self.down
    drop_table :tasks
  end
end

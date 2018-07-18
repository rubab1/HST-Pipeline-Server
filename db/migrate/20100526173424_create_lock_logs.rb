class CreateLockLogs < ActiveRecord::Migration[5.1]
  def self.up
    create_table :lock_logs do |t|
      t.references :pipeline
      t.string :entry
      t.references :event
      t.references :data_product
      t.references :user

      t.timestamps
    end
  end

  def self.down
    drop_table :lock_logs
  end
end

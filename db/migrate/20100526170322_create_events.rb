class CreateEvents < ActiveRecord::Migration[5.1]
  def self.up
    create_table :events do |t|
      t.string :name, :limit=>64
      t.string :value
      t.references :job
      t.string :jargs, :default=>''
      
      t.timestamps
    end
  end

  def self.down
    drop_table :events
  end
end

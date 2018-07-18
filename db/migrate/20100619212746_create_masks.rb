class CreateMasks < ActiveRecord::Migration[5.1]
  def self.up
    create_table :masks do |t|
      t.string :name, :limit=>64
      t.string :value
      t.string :source
      t.string :optionflags
      t.references :task

      t.timestamps
    end
  end

  def self.down
    drop_table :masks
  end
end

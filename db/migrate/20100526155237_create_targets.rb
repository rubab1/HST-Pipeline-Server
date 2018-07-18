class CreateTargets < ActiveRecord::Migration[5.1]
  def self.up
    create_table :targets do |t|
      t.string :name
      t.string :relativepath
      t.references :pipeline

      t.timestamps
    end
  end

  def self.down
    drop_table :targets
  end
end

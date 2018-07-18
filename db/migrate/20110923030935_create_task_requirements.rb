class CreateTaskRequirements < ActiveRecord::Migration[5.1]
  def self.up
    create_table :requirements do |t|
      t.string :name, :limit=>64
      t.string :value
      t.string :optionflags
      t.references :task
      t.timestamps
    end
  end

  def self.down
    drop_table :requirements
  end

end

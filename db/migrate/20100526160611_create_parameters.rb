class CreateParameters < ActiveRecord::Migration[5.1]
  def self.up
    create_table :parameters do |t|
      t.string :name, :limit=>64
      t.string :value
      t.string :ptype, :limit=>32
      t.string :group, :limit=>64
      t.string :description
      t.references :configuration
      t.boolean :volatile

      t.timestamps
    end
  end

  def self.down
    drop_table :parameters
  end
end

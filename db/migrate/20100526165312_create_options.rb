class CreateOptions < ActiveRecord::Migration[5.1]
  def self.up
    create_table :options do |t|
      t.references :optionable
      t.string :optionable_type
      t.string :name, :limit => 64
      t.string :value

      t.timestamps
    end
  end

  def self.down
    drop_table :options
  end
end

class AddCapabilitiesForNodes < ActiveRecord::Migration[5.1]
  def self.up
    create_table :node_capabilities do |t|
      t.string :name, :limit=>64
      t.string :value
      t.string :optionflags
      t.references :node
      t.timestamps
    end
  end

  def self.down
    drop_table :node_capabilities
  end

end

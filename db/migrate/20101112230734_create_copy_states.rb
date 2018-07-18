class CreateCopyStates < ActiveRecord::Migration[5.1]
  def self.up
    create_table :copy_states do |t|
      t.string :state
      t.references :data_product
      t.references :node

      t.timestamps
    end
  end

  def self.down
    drop_table :copy_states
  end
end

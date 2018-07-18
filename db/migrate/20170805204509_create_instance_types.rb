class CreateInstanceTypes < ActiveRecord::Migration[5.1]
  def change
    create_table :instance_types do |t|
      t.string :name
      t.float :price
      t.timestamps
    end
  end
end

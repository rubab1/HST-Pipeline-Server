class CreateSourceTrees < ActiveRecord::Migration[5.1]
  def self.up
    create_table :source_trees do |t|
      t.string :svnurl
      t.string :srcpath
      t.references :pipeline

      t.timestamps
    end
  end

  def self.down
    drop_table :source_trees
  end
end

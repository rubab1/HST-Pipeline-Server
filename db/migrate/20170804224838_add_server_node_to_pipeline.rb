class AddServerNodeToPipeline < ActiveRecord::Migration[5.1]
  def change
    add_column :pipelines, :server_node_id, :integer
  end
end

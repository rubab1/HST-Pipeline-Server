class NodeCapability < ActiveRecord::Base
  belongs_to :node

  validates_presence_of :name, :value
  validates_length_of :name, :minimum => 2


end

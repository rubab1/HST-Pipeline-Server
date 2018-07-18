class Target < ActiveRecord::Base
  belongs_to :pipeline
  has_many   :configurations, :dependent => :destroy 
  # attr_accessor :name, :relativepath, :pipeline_id 
end

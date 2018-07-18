class Parameter < ActiveRecord::Base
  belongs_to :configuration
  # attr_accessor :name, :value, :ptype, :group, :description, :configuration_id, :volatile 
end

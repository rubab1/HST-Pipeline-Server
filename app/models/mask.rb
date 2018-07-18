class Mask < ActiveRecord::Base
  belongs_to :task
  # attr_accessor :name, :value, :source, :optionflags
end

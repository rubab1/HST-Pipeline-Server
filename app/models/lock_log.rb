class LockLog < ActiveRecord::Base
  belongs_to :pipeline
  belongs_to :event
  belongs_to :data_product
  belongs_to :user
end

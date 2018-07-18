
# NOTE: should be ready only view of records in queue
class InfraDelayedJob < ActiveRecord::Base
 	self.table_name = "delayed_jobs"
end


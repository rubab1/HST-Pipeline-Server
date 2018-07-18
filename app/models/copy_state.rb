class CopyState < ActiveRecord::Base
  belongs_to :data_product
  belongs_to :node



  # A copy_state is the state of a copy of this date product on some
  # node somewhere
  #
  # State can be
  #   new:      it exists on the node, not on the S3 store
  #   insync:   it represents a valid copy of the S3 store
  #   updated:  the node's copy is newer and different than the S3 store
  #   outdated: the node's copy is older and different than the S3 store
  #   phantom:  the node's copy is a phantom bookmark of the real file.
  

end

class Option < ActiveRecord::Base
  belongs_to :optionable, :polymorphic => true
end

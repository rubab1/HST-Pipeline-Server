class Configuration < ActiveRecord::Base
  belongs_to :target
  has_many :data_products, :dependent => :destroy 
  has_many :parameters, :dependent => :destroy
  has_many :jobs, :dependent => :destroy 
  # attr_accessor :name, :description, :relativepath, :target_id
  # here because ".target" is an overloaded method by Ruby ;-(
  def Target
    self.target
  end


  #
  # copy the parameters from another configuration into this one
  #
  def copy_parameters(c)
    c.parameters.each do |p|
      @parameter = self.parameters.build(:name =>p.name, :value=>p.value,
        :ptype => p.ptype, :group => p.group, :description => p.description,
        :volatile => p.volatile)
      @parameter.save!
    end
  end

end

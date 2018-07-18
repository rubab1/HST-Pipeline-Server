class Task < ActiveRecord::Base
  belongs_to :pipeline
  has_many :jobs,  :dependent => :destroy
  has_many :masks, :dependent => :destroy
  has_many :options, :as =>:optionable, :dependent => :destroy
  has_many :requirements, :dependent => :destroy # Requirements are specifications for the kind of node that a task may run on

  # attr_accessor :name, :flags
  validates_presence_of :name, :pipeline
  validates_length_of :name, :minimum => 2

  def average_elapsed_run_time
    aert = self.TotalRunTime / self.nruns
  end

  def record_another_run(start_time, end_time)
    self.nruns = self.nruns + 1
    self.TotalRunTime += (end_time - start_time)
    self.save!
  end
  
end

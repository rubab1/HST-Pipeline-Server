class Job < ActiveRecord::Base
  belongs_to :task
  belongs_to :configuration
  belongs_to :node
  belongs_to :event      # the initiating event, if it exists
  
  has_many :events, :dependent => :destroy
  has_many :options, :as =>:optionable, :dependent => :destroy
  
  # attr_accessor :state, :pid, :task_id, :configuration_id, :node_id, :event_id

  def Job.create_from_task_and_config(t, c, o = "")
    #@job = Job.create(:task=> t, :configuration => c, :state => 'new', :options => o)
	@job = Job.create() do |j|
		j.task = t
		j.configuration = c
		j.state = 'new'
		if o.length > 0
			j.options = o
		end
	end
    @job.touch(:start_time)
    @job.save!
    @job
  end

  #
  # creates a job and configures its state for launching
  # via pipeline.process_queue
  #
  def Job.create_and_launch(t, c, e, o = "")
    #@job = Job.create(:task=> t, :configuration => c, :event => e, :state => 'new', :options => o)
	@job = Job.create() do |j|
		j.task = t
		j.configuration = c
		j.event = e
		j.state = 'new'
		if o.length > 0
			j.options = o
		end
	end
    @job.touch(:start_time)
    @job.save!
    @job
  end

  def mark_as_done
    touch(:end_time)
    self.task.record_another_run(self.start_time,self.end_time)
    node = self.node
    node.num_jobs -= 1
    node.save!
  end

  def is_exclusive?
    return self.is_exclusive
  end

  def Job.get_count_of_not_done_by_task(task_id)
    # NOTE could look at job state or end_time
    result = 0
    task_id = task_id.to_i # keep out non integer strings
    logger.debug("Job.get_count_of_task_not_ended : task_id = #{task_id.inspect}")
    result = Job.where(task_id: task_id, end_time: nil).count
    return result
  end

end

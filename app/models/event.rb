class Event < ActiveRecord::Base
  belongs_to :job
  has_many :options, :as =>:optionable, :dependent => :destroy
  # attr_accessor :name, :value, :jargs

  #
  # Once an event is created in the Pipeline
  # calling "fire" causes the masking to be checked and new jobs launched
  #
  def fire
    @job = self.job
    @task = @job.task
    @pipeline = @task.pipeline
    @jobs  = []

    @masks = Mask.find_by_sql "SELECT masks.* from masks, tasks WHERE (masks.name like '#{self.name}' OR masks.name='*') AND (masks.value like '#{self.value}' OR  masks.value='*')  AND (masks.source like '#{@task.name}' OR  masks.source='*') AND masks.task_id=tasks.id AND tasks.pipeline_id=#{@task.pipeline_id}"

    logger.info("event.fire : #{self.id} #{self.name} #{self.value} after mask")

    @masks.each do |m|
      task          = m.task
      configuration = @job.configuration
      j           = Job.create_and_launch task, configuration, self
      logger.info("event.fire : matched task #{task.name}")

      @jobs.push j
    end

    # NO - done via crontab now - @pipeline.process_queue
  end
  
end

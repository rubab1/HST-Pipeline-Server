class Requirement < ActiveRecord::Base
  belongs_to :task

  validates_presence_of :name, :value
  validates_length_of :name, :minimum => 2
  # attr_accessor :name, :value, :optionflags, :task_id
  def node_meets(a_node)
    logger.debug("node_meets: self = #{self.inspect}")
    logger.debug("node_meets: node = #{a_node.inspect}")
    result = false
    begin
      #  do work here
      case self.name
        when "max_num_running"
          v = self.value.to_i # force to an int
          logger.debug("node_meets: max_num_running = #{v}")
          count = Job.get_count_of_not_done_by_task(self.task_id)
          logger.debug("node_meets: max_num_running, found #{count}")
          result = (count >= v) ? false : true
        else
          result = true
      end
    catch Exception => e
      logger.error("node_meets: exception => #{e.inspect}")
      result = false
    end
    logger.debug("node_meets: result => #{result}")
    return result
  end

end

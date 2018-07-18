class ServerLock < ActiveRecord::Base

  def ServerLock.assert_lock_for ( lock_name, owner_name, process_name, pid=nil  )
    # logger.info("ServerLock.assert_lock_for: begin , name = #{lock_name} ...")
    begin
      lock = ServerLock.where(lock_name: lock_name).first
      # logger.info("ServerLock.assert_lock_for: name = #{lock_name} -> lock #{lock.inspect} ")
      if (lock.nil?)
		lock = ServerLock.create() do |l|
			l.lock_name = lock_name
			l.owner_name = owner_name
			l.process_name = process_name
			l.pid = pid
		end
        #lock = ServerLock.create(:lock_name => lock_name, :owner_name => owner_name, :process_name => process_name, :pid => pid)
        lock.save!
      else
        logger.info("ServerLock.assert_lock_for: lock already exists #{lock.inspect} ")
        raise "Lock Already Exists"
      end
    # rescue Exception => e
    rescue ActiveRecord::RecordInvalid => e
      logger.info("ServerLock.assert_lock_for: EXCEPTION #{e.inspect}")
      raise e # TODO - something smarter ...
    end
    # logger.info("ServerLock.assert_lock_for: end.")
    return lock
  end

  def ServerLock.remove_locks_like ( lock_name )
    # logger.info("ServerLock.remove_locks_like: begin , name = #{lock_name} ...")
    begin
      ServerLock.delete_all([ "lock_name LIKE ?", "#{lock_name}%"])
    rescue Exception => e
      logger.info("ServerLock.remove_locks_like: EXCEPTION #{e.inspect}")
    end
    # logger.info("ServerLock.remove_locks_like: end.")
  end


end


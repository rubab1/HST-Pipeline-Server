class DataProduct < ActiveRecord::Base
  belongs_to :configuration
  # belongs_to :lockowner
  has_many :options, :dependent => :destroy, :as => :optionable
  has_many :copy_states, :dependent => :destroy


  # A copy_state is the state of a copy of this date product on some
  # node somewhere
  #
  # State can be
  #   new:      it exists on the node, not on the S3 store
  #   insync:   it represents a valid copy of the S3 store
  #   updated:  the node's copy is newer and different than the S3 store
  #   outdated: the node's copy is older and different than the S3 store
  #   phantom:  the node's copy is a phantom bookmark of the real file.

  #
  # There is also a state (s3state) representing the state of the
  # "official" copy on the S3 store
  #  empty:       it exists on the node, not on the S3 store
  #  current:     it represents the most up-to-date version of the data
  #  not-current: the data on S3 is out-of-date with respect to some node
  #  



      @@COMMONFILTERS = [
        "F105W",
        "F125W",
        "F110W",
        "F140W",
        "F160W",
        "F218W",
        "F220W",
        "F225W",
        "F250W",
        "F255W",
        "F275W",
        "F300W",
        "F330W",
        "F336W",
        "F380W",
        "F390W",
        "F435W",
        "F438W",
        "F439W",
        "F450W",
        "F475W",
        "F555W",
        "F569W",
        "F606W",
        "F622W",
        "F625W",
        "F675W",
        "F702W",
        "F775W",
        "F791W",
        "F814W"].freeze

    @@MIDDLEFILTERS = [
        "F098M",
        "F122M",
        "F127M",
        "F139M",
        "F153M",
        "F160BW",
        "F170W",
        "F185W",
        "F200LP",
        "F300X",
        "F350LP",
        "F390M",
        "F410M",
        "F467M",
        "F475X",
        "F547M",
        "F550M",
        "F600LP",
        "F621M",
        "F689M",
        "F763M",
        "F785LP",
        "F845M",
        "F850LP",
        "F1042M"].freeze


    @@NARROWFILTERS = [
        "F 126 N",
        "F 128 N",
        "F 130 N",
        "F 132 N",
        "F 164 N",
        "F 167 N",
        "F 280 N",
        "F 343 N",
        "F 344 N",
        "F 373 N",
        "F 375 N",
        "F 390 N",
        "F 395 N",
        "F 437 N",
        "F 469 N",
        "F 487 N",
        "F 502 N",
        "F 588 N",
        "F 631 N",
        "F 645 N",
        "F 656 N",
        "F 657 N",
        "F 658 N",
        "F 660 N",
        "F 665 N",
        "F 673 N",
        "F 680 N",
        "F 892 N",
        "F 953 N"].freeze


  def filtername
    @filtname = "unknown"
    multi = false

    @bfc = 0
    @bfm = 0
    @bfn = 0

    @bfc = self.binfiltercommon unless self.binfiltercommon.nil?
    @bfm = self.binfiltermiddle unless self.binfiltermiddle.nil?
    @bfn = self.binfilternarrow unless self.binfilternarrow.nil?


    if ( @bfc.nonzero?) then
      fs = @bfc
      i = 0;
      @@COMMONFILTERS.each do |f|
        if ( (fs[i]).nonzero? )
          puts "found #{f}"
          if (!multi)
            @filtname = f
            multi = true
          else
            @filtname << ', '
            @filtname << f
          end
        end
        i = i+1
      end
    end

    if ( @bfm.nonzero?) then
      fs = @bfm
      i = 0;
      @@MIDDLEFILTERS.each do |f|
        if ( (fs[i]).nonzero? )
          puts "found #{f}"
          if (!multi)
            @filtname = f
            multi = true
          else
            @filtname << ', '
            @filtname << f
          end
        end
        i = i+1
      end
    end

    if ( @bfn.nonzero?) then
      fs = @bfn
      i = 0;
      @@NARROWFILTERS.each do |f|
        if ( (fs[i]).nonzero? )
          puts "found #{f}"
          if (!multi)
            @filtname = f
            multi = true
          else
            @filtname << ', '
            @filtname << f
          end
        end
        i = i+1
      end
    end
    @filtname
  end

  #
  # Attempts to give a lock to the requester
  #
  # The locktype string is the type (read or write) followed by
  # a space delimited set of node numbers (which should only be one
  # number in the case of a write
  #
  def attemptlock(node, lockstring, duration)
    self.locktype = "" if (self.locktype.nil?)
    
    lockset = self.locktype.split(' ') 
    # logger.debug("data_product.attemptlock, lockset[0]=#{lockset[0]}, expired=#{self.lockexpired?} ")
    if (lockset.empty? || self.lockexpired? || (!lockset[0].eql?("read") && !lockset[0].eql?("write")) )
      self.locktype = "#{lockstring} #{node}"
      self.save!
    else
      # if it's a read lock, we can extend the expiration and add the new lock
      if lockset[0].eql?("read") && lockstring.eql?("read")
        logger.debug(" extending read lock")
        lockset.push(node)
        self.locktype = lockset.join(' ')
        self.lockexpire = duration.seconds.from_now
        self.save!
      end
    end
    self
  end
  
  #
  # releases a lock if the node is holding one or in any case if 
  # everything is expired
  #
  def releaselock(node)
    if (self.lockexpired?)
      self.locktype = ""
      self.lockexpire = DateTime.now
    else
      lockset = self.locktype.split(' ')
      if (lockset.delete(node).nil?)
        return
      end

      if (lockset[0].eql?("write") || lockset.size <= 1)
        self.locktype = ""
        self.lockexpire = DateTime.now
      else
        self.locktype = lockset.join(' ')
      end
    end
    self.save!
  end

  def lockexpired?
    if (self.lockexpire.nil? || self.lockexpire.past?)
      self.locktype = ""
      self.lockgranted = ""
      self.lockexpire = ""
      self.save!
      return true
    end
    return false
  end

end

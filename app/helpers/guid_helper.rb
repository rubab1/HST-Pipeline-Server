
require 'guid'

module GuidHelper
  #def before_create()
   def set_guid
    if (self.guid.nil?)
      prefix = nil
      begin
        prefix = self.get_guid_prefix
      rescue Exception
      end
      prefix = self.class.name if prefix.nil?
      prefix.downcase!
      
      # special case for classes with short_guid_length method defined
      begin
        guid_len  = self.get_short_guid_length.to_i
        while true
          a_guid = Guid.for(prefix).to_s[0,guid_len]
          self.guid = a_guid if self.class.find_by_guid(a_guid).nil?
          break if ! self.guid.nil?
        end
      rescue Exception
      end
    # catchall case
    self.guid = Guid.for(prefix) if (self.guid.nil?)
    end
    return self.guid
  end
end


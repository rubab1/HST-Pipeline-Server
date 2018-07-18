# ==============================================================================
# tool to help debugging
# show a list of logs
# view and filter ( and perhaps later merge views ) of logs
# ==============================================================================
class LogsController < ApplicationController

  before_action :authenticate
  layout 'main'

  AVAILABLE_LOGS = { :rpipeline => "#{Rails.root}/log/#{Rails.env}.log" }

  def index
    # show a list of available logs
    @logs = AVAILABLE_LOGS
  end

  def show
    # show the specified log
    @log_name  = params[:id]
    @log_file = AVAILABLE_LOGS[@log_name.to_sym]
    logger.debug("log_name = #{@log_name.inspect} => #{@log_file.inspect} ")
    @num_last_lines = params[:num_last_lines].to_i # NOTE to_i
    @num_last_lines = 100 if @num_last_lines < 1
    options = { :num_last_lines => @num_last_lines }
    @filters_string = params[:filters]
    if ! @filters_string.blank?
      filters_data = @filters_string.split '|'
      options[:filters] = filters_data
    end
    logger.debug("options = #{options.inspect}")
    @data = _get_log_data(@log_name,@log_file,options)
  end


  private
  def _get_log_data(log_name,log_file, options={} )
    data = ''
    return "invalid log #{log_name.inspect}" if (log_name.blank? || log_file.blank?)
    num_last_lines = options[:num_last_lines].to_i #NOTE: to_i turns non numbers to 0
    num_last_lines = 100 if num_last_lines < 1
    filters = options[:filters]

    begin
      open("|tail -#{num_last_lines} #{log_file}") do |fd| 
        fd.each do |line|
          #TODO be smarter with fancy reg-ex
          if filters.nil?
              data += line 
          else
            filters.each do |filter|
              if line.include? filter
                data += line 
                break
              end
            end   
          end   
        end   
      end 
    end
    # rescue Exception => e
      # logger.info("caught #{e.inspect}")
      # data = "problem with log #{log_name} : #{e.inspect}"
    # end 
    return data
  end

end

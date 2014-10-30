module MockDnsServer

class ConditionalAction

  attr_accessor :condition, :action, :description, :max_uses, :use_count


  # @param condition a proc/lambda that, when called with request as a param, returns
  #        true or false to determine whether or not the action will be executed
  # @param action the code (lambda or proc) to be executed; takes incoming message,
  #        sender, server context, and (optionally) protocol as parameters
  #        and performs an action
  # @param max_uses maximum number of times this action should be executed
  # @return the value returned by the action, e.g. the message, or array of messages, it sent
  def initialize(condition, action, max_uses)
    @condition = condition
    @action = action
    @max_uses = max_uses
    @use_count = 0
  end


  def increment_use_count
    @use_count += 1
  end

  def to_s
    "#{super.to_s}; condition: #{condition.to_s}, action = #{action.to_s}, max_uses = #{max_uses}"
  end

  def eligible_to_run?
    max_not_reached = max_uses.nil? || use_count < max_uses
    max_not_reached && condition.call
  end

  def run(request, sender, context, protocol)
    # TODO: Output to history?
    action.call(request, sender, context, protocol)
  end

end
end

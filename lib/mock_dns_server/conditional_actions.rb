require 'forwardable'
require 'thread_safe'

module MockDnsServer

  class ConditionalActions

    attr_reader :context

    extend Forwardable

    def_delegators :@context, :port, :history, :verbose

    def initialize(context)
      @context = context
      @records = ThreadSafe::Array.new
    end


    def find_conditional_action(request, protocol)
      @records.detect { |cond_action| cond_action.condition.call(request, protocol) }
    end


    def respond_to(request, sender, protocol)
      conditional_action = find_conditional_action(request, protocol)

      if conditional_action
        puts 'Found action' if verbose
        history.add_incoming(request, sender, protocol, conditional_action.description)
        conditional_action.run(request, sender, context, protocol)
        puts 'Completed action' if verbose
        conditional_action.increment_use_count
        handle_use_count(conditional_action)
      else
        puts 'Action not found' if verbose
        history.add_action_not_found(request)
      end
    end


    def handle_use_count(conditional_action)
      max_uses = conditional_action.max_uses
      we_care = max_uses && max_uses > 0
      if we_care && conditional_action.use_count >= max_uses
        history.add_conditional_action_removal(conditional_action.description)
        @records.delete(conditional_action)
      end

    end

    def add(conditional_action)
      # Place new record at beginning of array, so that the most recently
      # added records are found first.
      @records.unshift(conditional_action)
    end


    def remove(conditional_action)
      @records.delete(conditional_action)
    end


    def size
      @records.size
    end


    def empty?
      size == 0
    end
  end
end

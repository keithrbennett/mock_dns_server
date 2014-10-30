require 'dnsruby'
require 'forwardable'

require 'mock_dns_server/conditional_actions'
require 'mock_dns_server/history'
require 'mock_dns_server/message_builder'

module MockDnsServer

class ServerContext

  include MessageBuilder
  extend Forwardable

  def_delegators :@conditional_actions, :respond_to

  attr_reader :server, :port, :host, :timeout_secs, :mutex,
              :conditional_actions, :history, :verbose

  #def shutdown_requested?; @shutdown_requested          end
  #def request_shutdown;    @shutdown_requested = true   end


  def initialize(server, options = {})
    @server = server
    @port = options[:port]
    @host = options[:host]
    @timeout_secs = options[:timeout_secs]
    @verbose = options[:verbose]
    @mutex = Mutex.new
    @conditional_actions = ConditionalActions.new(self)
    @history = History.new(self)
  end


  def with_mutex(&block)

    start_time = Time.now
    duration = ->() do
      now = Time.now
      elapsed_in_usec = (now - start_time) * 1_000_000
      start_time = now
      "#{elapsed_in_usec} usec"
    end

    #puts "#{Thread.current}: Waiting for mutex..."
    mutex.synchronize do
      #puts "time to get mutex: #{duration.()}"
      block.call
      #puts "time using mutex: #{duration.()}"
    end
  end


end

end

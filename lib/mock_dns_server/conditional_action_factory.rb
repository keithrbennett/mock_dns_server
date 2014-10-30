require 'mock_dns_server/conditional_action'
require 'mock_dns_server/action_factory'
require 'mock_dns_server/predicate_factory'

module MockDnsServer


# Provides conditional actions that may be commonly used.
class ConditionalActionFactory

  attr_reader :action_factory

  def initialize
    @action_factory = ActionFactory.new
    @predicate_factory = PredicateFactory.new
  end


  # Probably only used for testing, this ConditionalAction will unconditionally
  # respond with the same object it receives.
  def echo
    ConditionalAction.new(PredicateFactory.new.always_true, action_factory.echo, 0)
  end


  def specified_a_response(qname, answer_string, times = 0)
    predicate = @predicate_factory.a_request(qname)
    response = MessageBuilder.specified_a_response(answer_string)
    action = @action_factory.send_message(response)
    ConditionalAction.new(predicate, action, times)
  end


  # Causes a SOA response with the specified serial to be sent upon receiving a SOA request.
  # If zone is specified, the action will only be performed if the request specifies that zone.
  def soa_response(serial, zone, times = 0)
    predicate = @predicate_factory.all(@predicate_factory.qname(zone), @predicate_factory.soa)
    response = MessageBuilder.soa_response(name: zone,  serial: serial)
    action = @action_factory.send_message(response)
    ConditionalAction.new(predicate, action, times)
  end


  # Sets up the server to respond to SOA requests with the given SOA, and respond to AXFR
  # requests with the specified data, wrapped in SOA responses.
  def zone_load(serial_history, times = 0)
    pr = @predicate_factory
    predicate = pr.all(pr.qname(serial_history.zone), pr.zone_load)
    action = ActionFactory.new.zone_load(serial_history)
    ConditionalAction.new(predicate, action, times)
  end
end
end

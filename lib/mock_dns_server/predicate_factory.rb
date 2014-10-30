require 'mock_dns_server/message_transformer'

module MockDnsServer

# Each method returns a predicate in the form of a lambda or proc that takes an
# incoming object (usually a Dnsruby::Message) object as a parameter and returns
# (as predicates do) true or false.
class PredicateFactory

  # shorthand for the MessageTransformers instance
  def mt(message)
    MessageTransformer.new(message)
  end

  # TODO: Case insensitive?
  # TODO: Add sender to signature for tcp/udp, etc.?

  def all(*predicates)
    ->(message, protocol = nil) do
      predicates.all? { |p| p.call(message, protocol) }
    end
  end

  def any(*predicates)
    ->(message, protocol = nil) do
      predicates.any? { |p| p.call(message, protocol) }
    end
  end

  def none(*predicates)
    ->(message, protocol = nil) do
      predicates.none? { |p| p.call(message, protocol) }
    end
  end

  def dns
    ->(message, _ = nil) { message.is_a?(Dnsruby::Message) }
  end

  def soa
    qtype('SOA')
  end

  def ixfr
    qtype('IXFR')
  end

  def axfr
    qtype('AXFR')
  end

  def xfr
    any(axfr, ixfr)
  end

  # Returns true for messages relating to data from the zone load.
  def zone_load
    any(xfr, soa)
  end

  # Convenience method for testing for a specific qtype and qname.
  def qtype_and_qname(qtype, qname)
    all(qtype(qtype), qname(qname))
  end

  # Convenience method for testing a request of qtype 'A' with the given qname.
  def a_request(qname)
    qtype_and_qname('A', qname)
  end

  def qtype(qtype)
    ->(message, _ = nil) do
      dns.(message) && eq_case_insensitive(mt(message).qtype, qtype)
    end
  end

  def qclass(qclass)
    ->(message, _ = nil) { dns.(message) && eq_case_insensitive(mt(message).qclass, qclass) }
  end

  def qname(qname)
    ->(message, _ = nil) { dns.(message) && eq_case_insensitive(mt(message).qname, qname) }
  end

  def from_tcp
    ->(_, protocol) { protocol == :tcp }
  end

  def from_udp
    ->(_, protocol) { protocol == :udp }
  end

  def always_true
    ->(_, _) { true }
  end

  def always_false
    ->(_, _) { false }
  end

  private

  def eq_case_insensitive(s1, s2)
    s1.downcase == s2.downcase
  end

end
end

module MockDnsServer

# Lambdas that transform a message into something else, usually a message component such as domain or qtype.
class MessageTransformer

  attr_reader :message

  # Initialize the transformer with a message.
  # @param dns_message can be either a Dnsruby::Message instance or binary wire data
  def initialize(dns_message)
    self.message = dns_message
  end


  def message=(dns_message)
    @message = dns_message.is_a?(String) ? Dnsruby::Message.decode(dns_message) : dns_message
  end


  # A SOA record is usually in the answer section, but in the case of IXFR requests
  # it will be in the authority section.
  #
  # @location defaults to :answer, can override w/:authority
  def serial(location = :answer)
    return nil if message.nil?

    target_section = message.send(location == :answer ? :answer : :authority)
    return nil if target_section.nil?

    soa_answer = target_section.detect { |record| record.is_a?(Dnsruby::RR::IN::SOA) }
    soa_answer ? soa_answer.serial : nil
  end


  # @return the message's qtype as a String
  def qtype
    dnsruby_type_instance = question_attr(:qtype)
    Dnsruby::Types.to_string(dnsruby_type_instance)
  end


  # @return the message's qname as a String
  def qname
    question_attr(:qname)
  end


  # @return the message's qclass as a String
  def qclass
    question_attr(:qclass)
  end


  def question_attr(symbol)
    question = first_question
    question ? question.send(symbol).to_s : nil
  end


  def first_question
    has_question = message &&
        message.question &&
        message.question.first &&
        message.question.first.is_a?(Dnsruby::Question)

    has_question ? message.question.first : nil
  end


  def answer_count(answer_type)
    message.answer.select { |a| a.rr_type.to_s == answer_type}.count
  end
end
end

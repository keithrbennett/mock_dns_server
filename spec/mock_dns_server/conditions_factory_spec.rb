require 'dnsruby'
require 'spec_helper'
require 'mock_dns_server/predicate_factory'

module MockDnsServer

describe PredicateFactory do

  describe "Conditions.message_qtype" do

    subject { PredicateFactory.new.qtype('SOA') }

    it "correctly returns true" do
      message = Dnsruby::Message.new('com', Dnsruby::Types.SOA)
      expect(subject.call(message)).to be true
    end

    it "correctly returns false" do
      message = Dnsruby::Message.new('ruby-lang.org', Dnsruby::Types.A)
      expect(subject.call(message)).to be false
    end

  end


  describe "Conditions.message_qname" do

    subject { PredicateFactory.new.qname('ruby-lang.org') }

    it "correctly returns true" do
      message = Dnsruby::Message.new('ruby-lang.org', 'A')
      expect(subject.call(message)).to be true
    end

    it "correctly returns false" do
      message = Dnsruby::Message.new('python.org', 'A')
      expect(subject.call(message)).to be false
    end
  end

  describe "Conditions.message_qclass" do

    subject { PredicateFactory.new.qclass('IN')}

    it "correctly returns true" do
      message = Dnsruby::Message.new('ruby-lang.org', 'A', 'IN')
      expect(subject.call(message)).to be true
    end

    it "correctly returns false" do
      message = Dnsruby::Message.new('ruby-lang.org', 'A', 'CH')
      expect(subject.call(message)).to be false
    end

  end

end
end

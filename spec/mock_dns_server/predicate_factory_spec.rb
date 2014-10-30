require_relative '../spec_helper'

require 'dnsruby'
require 'mock_dns_server/predicate_factory'

module MockDnsServer

  describe PredicateFactory do

    subject { PredicateFactory.new }

    it '.always_true works' do
      func = subject.always_true
      expect(func.call(nil, nil)).to be true
    end


    it '.always_false works' do
      func = subject.always_false
      expect(func.call(nil, nil)).to be false
    end

    
    it '.and works' do
      t = subject.always_true
      f = subject.always_false

      composite_func = subject.all(t, t)
      expect(composite_func.call(nil, nil)).to be true

      composite_func = subject.all(t, f)
      expect(composite_func.call(nil, nil)).to be false
    end

    it '.not works' do
      t = subject.always_true
      f = subject.always_false

      composite_func = subject.none(f, f)
      expect(composite_func.call(nil, nil)).to be true

      composite_func = subject.none(t, f)
      expect(composite_func.call(nil, nil)).to be false
    end

    it '.or works' do
      t = subject.always_true
      f = subject.always_false

      composite_func = subject.any(t, f)
      expect(composite_func.call(nil, nil)).to be true

      composite_func = subject.any(f, f)
      expect(composite_func.call(nil, nil)).to be false
    end

    it 'qname works' do
      message = Dnsruby::Message.new('amazon.com', 'A')

      predicate = subject.qname('amazon.com')
      expect(predicate.(message)).to be true

      predicate = subject.qname('ruby-lang.org')
      expect(predicate.(message)).to be false
    end

    it 'qtype works' do
      message = Dnsruby::Message.new('amazon.com', 'A')

      predicate = subject.qtype('A')
      expect(predicate.(message)).to be true

      predicate = subject.qtype('SOA')
      expect(predicate.(message)).to be false

    end

    it 'qclass works' do
      message = Dnsruby::Message.new('amazon.com', 'A', 'CH')

      predicate = subject.qclass('CH')
      expect(predicate.(message)).to be true

      predicate = subject.qclass('ZZ')
      expect(predicate.(message)).to be false
    end

    it 'soa works' do
      message = Dnsruby::Message.new('com', 'SOA')
      expect(subject.soa.(message)).to be true

      message = Dnsruby::Message.new('x.com', 'A')
      expect(subject.soa.(message)).to be false
    end

    it 'axfr works' do
      message = Dnsruby::Message.new('com', 'AXFR')
      expect(subject.axfr.(message)).to be true

      message = Dnsruby::Message.new('x.com', 'A')
      expect(subject.axfr.(message)).to be false
    end

    it 'ixfr works' do
      message = Dnsruby::Message.new('com', 'IXFR')
      expect(subject.ixfr.(message)).to be true

      message = Dnsruby::Message.new('x.com', 'A')
      expect(subject.ixfr.(message)).to be false
    end


    it 'qtype_and_qname works' do
      message = Dnsruby::Message.new('com', 'SOA')
      predicate = subject.qtype_and_qname('SOA', 'com')
      expect(predicate.(message)).to be true
    end

    it 'a_request works' do
      message = Dnsruby::Message.new('amazon.com', 'A')

      predicate = subject.a_request('amazon.com')
      expect(predicate.(message)).to be true

      predicate = subject.a_request('ruby-lang.org')
      expect(predicate.(message)).to be false

      predicate = subject.qname('ruby-lang.org')
      expect(predicate.(message)).to be false

      message = Dnsruby::Message.new('amazon.com', 'SOA')
      predicate = subject.a_request('amazon.com')
      expect(predicate.(message)).to be false
    end


    it 'is case insensitive' do
      message = Dnsruby::Message.new('AmAzOn.CoM', 'a')

      expect(subject.qtype('A').(message)).to be true
      expect(subject.qname('amazon.com').(message)).to be true
    end
  end



end

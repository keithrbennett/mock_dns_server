require_relative '../spec_helper'

require 'dnsruby'
require 'mock_dns_server/history_inspections'
require 'mock_dns_server/message_builder'

module MockDnsServer

describe HistoryInspections do

  include MessageBuilder

  let (:hi) { HistoryInspections.new }

  let (:test_data) do
    soa_opts = { name: 'com', mname: 'a.gtld-servers.net.', serial: 1001 }

    [
        { type: :outgoing, message: Dnsruby::Message.new('ruby-lang.org'), protocol: :udp, id: 1 },
        { type: :outgoing, message: Dnsruby::Message.new('ruby-lang.org'), protocol: :tcp, id: 2 },

        { type: :incoming, message: soa_response(soa_opts), protocol: :udp, id: 3 },
        { type: :incoming, message: soa_response(soa_opts), protocol: :tcp, id: 4 },

        { type: :incoming, message: specified_a_response("foo.example.com. 86400 A 10.1.2.3"), protocol: :udp, id: 5 },
        { type: :incoming, message: specified_a_response("foo.example.com. 86400 A 10.1.2.3"), protocol: :tcp, id: 6 },
    ]
  end

  def ids(records)
    records.map { |rec| rec[:id] }
  end

  it 'correctly tests for incoming' do
    inspection = hi.type(:incoming)
    result = hi.apply(test_data, inspection)
    expect(ids(result)).to eq([3, 4, 5, 6])
  end

  it 'correctly tests for outgoing' do
    inspection = hi.type(:outgoing)
    result = hi.apply(test_data, inspection)
    expect(ids(result)).to eq([1, 2])
  end

  it 'correctly tests for udp' do
    inspection = hi.protocol(:udp)
    result = hi.apply(test_data, inspection)
    expect(ids(result)).to eq([1, 3, 5])
  end

  it 'correctly tests for tcp' do
    inspection = hi.protocol(:tcp)
    result = hi.apply(test_data, inspection)
    expect(ids(result)).to eq([2, 4, 6])
  end

  it 'correctly tests for qtype' do
    inspection = hi.qtype('SOA')
    result = hi.apply(test_data, inspection)
    expect(ids(result)).to eq([3, 4])
  end

  it 'correctly operates with the all predicate' do
    inspection = hi.all(hi.qtype('SOA'), hi.protocol(:udp))
    result = hi.apply(test_data, inspection)
    expect(ids(result)).to eq([3])
  end

  it 'correctly operates with the any predicate' do
    inspection = hi.any(hi.qtype('SOA'), hi.protocol(:udp))
    result = hi.apply(test_data, inspection)
    expect(ids(result)).to eq([1, 3, 4, 5])
  end

  it 'correctly operates with the none predicate' do
    inspection = hi.none(hi.qtype('SOA'), hi.protocol(:udp))
    result = hi.apply(test_data, inspection)
    expect(ids(result)).to eq([2, 6])
  end


end
end

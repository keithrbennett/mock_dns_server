require 'spec_helper'
require 'mock_dns_server/serial_transaction'
require 'mock_dns_server/message_builder'

module MockDnsServer

describe SerialTransaction do

  let(:rrs) do [
      MessageBuilder.rr('A', 'abc.com', '1.2.3.4'),
      MessageBuilder.rr('A', 'abc.com', '5.6.7.8')
  ] end

  context 'SerialTransaction#ixfr_records' do

    it "positions SOA's, additions, and deletions correctly" do
      txn = SerialTransaction.new('ruby-lang.org', 1002)
      txn.additions = [rrs.first]
      txn.deletions = [rrs.last]
      records = txn.ixfr_records(1001)

      expect(records[0].type.to_s).to eq('SOA')
      expect(records[0].serial).to eq(1001)

      expect(records[1].type.to_s).to eq('A')
      expect(records[1].rdata.to_s).to eq('5.6.7.8')

      expect(records[2].type.to_s).to eq('SOA')
      expect(records[2].serial).to eq(1002)

      expect(records[3].type.to_s).to eq('A')
      expect(records[3].rdata.to_s).to eq('1.2.3.4')
    end
  end

end
end

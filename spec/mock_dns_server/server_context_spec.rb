require_relative '../spec_helper'

require 'mock_dns_server/server_context'

module MockDnsServer

  describe ServerContext do

    subject { ServerContext.new(nil) }

    it 'should wrap a block in a mutex without raising an exception' do
      n = 0
      block = ->() do
        subject.with_mutex { n = 1 }
      end
      expect(block).to_not raise_exception
      expect(n).to eq(1) # prove the block was executed
    end
  end
end

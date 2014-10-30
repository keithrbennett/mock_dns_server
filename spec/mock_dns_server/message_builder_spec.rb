require_relative '../spec_helper'

require 'mock_dns_server/message_builder'

module MockDnsServer

describe MessageBuilder do

  include MessageBuilder

  it 'creates dummy A records correctly' do
    num_records = 3
    response = dummy_a_response(num_records, 'ruby-lang.org')
    expect(response.answer.size).to eq(num_records)
  end

end
end

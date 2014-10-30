require_relative '../spec_helper'

require 'mock_dns_server/history'
require 'mock_dns_server/server'
require 'mock_dns_server/conditional_action_factory'


module MockDnsServer


  describe History do

    subject { History.new(nil) }
    let(:options) { { port: 9999 } }
    let(:sample_message) { 'Hello from RSpec' }
    let(:caf)  { ConditionalActionFactory.new }

    it 'should report the correct size' do
      n = 3
      n.times { |n| subject.add_incoming(nil, nil, nil) }
      expect(subject.size).to eq(n)
    end


    it 'should retain its content even after its copy is cleared' do
      n = 3
      n.times { |n| subject.add_incoming(nil, nil, nil) }
      copy = subject.copy
      copy.clear
      expect(subject.size).to eq(n)
    end


    it 'should create a new copy for each clone' do
      n = 3
      n.times { |n| subject.add_incoming(nil, nil, nil) }
      clone1 = subject.copy
      clone2 = subject.copy
      expect(clone1).not_to equal(clone2)
    end


    it 'should clone each record in the array' do
      subject.add_incoming(nil, nil, nil)
      clone1 = subject.copy
      clone2 = subject.copy
      expect(clone1.first).not_to equal(clone2.first)
    end


    it 'should contain entries from traffic' do

      Server.with_new_server(options) do |server|
        server.add_conditional_action(caf.echo)
        server.start

        socket = UDPSocket.new
        socket.send(sample_message, 0, '127.0.0.1', options[:port])
        _, _ = socket.recvfrom(10_000)
        history = server.history_copy
        expect(history.size > 0 && history.first[:type] == :incoming).to be true
      end
    end
  end
end

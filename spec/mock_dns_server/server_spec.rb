require_relative '../spec_helper'

require 'dnsruby'
require 'awesome_print'

require 'mock_dns_server/action_factory'
require 'mock_dns_server/conditional_action_factory'
require 'mock_dns_server/message_builder'
require 'mock_dns_server/message_helper'
require 'mock_dns_server/message_transformer'
require 'mock_dns_server/predicate_factory'
require 'mock_dns_server/serial_history'
require 'mock_dns_server/server'

module MockDnsServer

  MB = MessageBuilder

  describe Server do

    # This can be enabled temporarily if there are problems with the port being in use.
    # before(:each) do
    #   Server.kill_all_servers
    # end

    let(:port) { 9999 }
    let(:host) { '127.0.0.1' }
    let(:options) { { host: host, port: port } }
    # let(:options) { { host: host, port: port, verbose: true } }
    let(:verbose_options) { options.merge({ verbose: true }) }
    let(:sample_message) { 'Hello from RSpec' }
    let(:pf)   { PredicateFactory.new }
    let(:af)   { ActionFactory.new }
    let(:caf)  { ConditionalActionFactory.new }
    let(:mb)   { MessageBuilder.new }

    #it 'runs an echo server' do
    #  opts = verbose_options.merge(host: '10.0.1.8')
    #  ap opts
    #  Server.with_new_server(opts) do |server|
    #    server.add_conditional_action(ConditionalActionFactory.new.echo)
    #    server.start
    #    sleep 1000000
    #  end
    #end


    it 'can be created and destroyed twice successfully' do
      2.times do
        server = Server.new(options).start
        server.wait_until_ready
        server.close
      end
    end

    it 'gets created and destroyed' do

      server = Server.new(options)

      expect(server.ready?).to be false
      expect(server.closed?).to be false

      server.start.wait_until_ready
      expect(server.ready?).to be true
      expect(server.closed?).to be false
      server.close
      expect(server.closed?).to be true
    end


    it 'can be created and destroyed twice successfully' do
      2.times do
        server = Server.new(options).start
        server.wait_until_ready
        server.close
      end
    end

    it 'gets and replies to a simple message with TCP' do
      Server.with_new_server(options) do |server|
        server.add_conditional_action(ConditionalActionFactory.new.echo)
        server.start.wait_until_ready
        client_socket = TCPSocket.open(host, port)
        client_socket.write(MessageHelper.tcp_message_package_for_write(sample_message))
        message = MessageHelper.read_tcp_message(client_socket)
        expect(message).to eq(sample_message)
        # TODO: Close these sockets?
      end
    end

    it 'instructs the server correctly to be an echo server' do
      Server.with_new_server(options) do |server|
        server.add_conditional_action(ConditionalActionFactory.new.echo)
        server.start.wait_until_ready
        socket = UDPSocket.new
        socket.send(sample_message, 0, host, port)
        request_received, _ = socket.recvfrom(10_000)
        expect(request_received).to eq(sample_message)
      end
    end



    it 'gets a simple message with UDP' do

      Server.with_new_server(options) do |server|

        server.start do |request, sender, _|
          server.send_udp_response(sender, request)
        end

        socket = UDPSocket.new
        server.wait_until_ready
        socket.send(sample_message, 0, host, port)
        request_received, _ = socket.recvfrom(10_000)
        expect(request_received).to eq(sample_message)
      end

    end


   it 'calculates conditional action counts correctly' do
      Server.with_new_server(options) do |server|
        expect(server.conditional_action_count).to eq(0)
        server.add_conditional_action(ConditionalActionFactory.new.echo)
        expect(server.conditional_action_count).to eq(1)
      end
    end


    it 'handles maximum counts correctly' do

      # TODO: Research whether the placing of the sleep calls in this test
      # (and possibly elsewhere) indicate design or documentation error.
      #
      ca1 = ConditionalAction.new(pf.always_true, af.constant('1'), 1)
      ca2 = ConditionalAction.new(pf.always_true, af.constant('2'), 1)

      Server.with_new_server(options) do |server|
        server.add_conditional_actions([ca1, ca2])
        expect(server.conditional_action_count).to eq(2)
        server.start.wait_until_ready

        socket = UDPSocket.new
        socket.send(sample_message, 0, host, port)
        request_received, _ = socket.recvfrom(10_000)
        expect(request_received).to eq('2')
        sleep 0.01
        expect(server.conditional_action_count).to eq(1)

        socket.send(sample_message, 0, host, port)
        request_received, _ = socket.recvfrom(10_000)
        expect(request_received).to eq('1')
        sleep 0.01
        expect(server.conditional_action_count).to eq(0)
      end
    end


    it 'correctly returns an A response' do

      domain_name = 'foo.example.com'
      response_data = "#{domain_name} 86400 A 10.1.2.3"

      Server.with_new_server(options) do |server|
        server.add_conditional_action(caf.specified_a_response(domain_name, response_data))
        server.start.wait_until_ready

        request = Dnsruby::Message.new(domain_name).encode
        socket = UDPSocket.new
        socket.send(request, 0, host, port)
        encoded_message, _ = socket.recvfrom(10_000)
        response = Dnsruby::Message.decode(encoded_message)

        expect(response.answer.size).to eq(1)
        answer = response.answer.first
        expect(answer).to be_a(Dnsruby::RR::IN::A)
        expect(answer.ttl).to eq(86400)
        expect(answer.name.to_s).to eq(domain_name)
        expect(answer.rdata.to_s).to eq('10.1.2.3')
        expect(answer.rr_type).to eq('A')
      end
    end


    it 'should not provide access to its internals' do
      internal_methods = [:history, :conditional_actions]
      server = Server.new(options)
      errors = internal_methods.select { |pm| server.respond_to?(pm) }
      server.close
      expect(errors).to eq([])
    end


    it 'should get a DNS message correctly with UDP' do
      Server.with_new_server(options) do |server|

        server.add_conditional_action(caf.echo)
        server.start.wait_until_ready

        socket = UDPSocket.new
        wire_data = Dnsruby::Message.new('a.com').encode
        socket.send(wire_data, 0, host, port)
        response_wire_data, _ = socket.recvfrom(2000)
        expect(server.is_dns_packet?(response_wire_data, :udp)).to be true
      end
    end


    it 'should instantiate without specifying an options hash' do
      old_verbose, $VERBOSE = $VERBOSE, nil # disable 'constant already initialized' warning
      default_port_sav = Server::DEFAULT_PORT
      Server::DEFAULT_PORT = 9999
      expect(->() { Server.new.close } ).to_not raise_error
      Server::DEFAULT_PORT = default_port_sav
      $VERBOSE = old_verbose
    end


    def test_dig_request(protocol)
      Server.with_new_server(options) do |server|
        response_data = "foo.example.com 86400 A 10.1.2.3"
        server.add_conditional_action(caf.specified_a_response('foo.example.com', response_data))
        server.start.wait_until_ready
        dig_command = "dig @#{options[:host]}  -p #{options[:port]}  foo.example.com #{protocol == :tcp ? ' +tcp' : ''}"
        dig_output = `#{dig_command}`
        expect(dig_output).to include('status: NOERROR')
        # expect(/foo.example.com.\s+86400\s+IN\s+A\s+10.1.2.3/ === dig_output).to be_true
        expect(dig_output).to match(/foo.example.com.\s+86400\s+IN\s+A\s+10.1.2.3/)
      end

    end

    it 'should respond correctly to a TCP dig request' do
      test_dig_request(:tcp)
    end


    it 'should respond correctly to a UDP dig request' do
      test_dig_request(:udp)
    end


    it 'should get a DNS message correctly with TCP' do
      Server.with_new_server(options) do |server|

        server.add_conditional_action(caf.echo)
        server.start.wait_until_ready

        client = TCPSocket.new('localhost', options[:port])

        message = Dnsruby::Message.new('a.com')
        wire_data = MessageHelper.tcp_message_package_for_write(message)
        client.write(wire_data)
        response_wire_data, _ = client.read(wire_data.size)
        expect(server.is_dns_packet?(response_wire_data, :udp)).to be true

        client.close
      end
    end


    it 'should return an AXFR response correctly' do

      zone = 'ruby-lang.org'
      dns_records = [
          MB.rr('A', 'x.ruby-lang.org', '1.1.1.2'),
          MB.rr('A', 'x.ruby-lang.org', '1.1.1.3'),
      ]

      Server.with_new_server(options) do |server|

        serial_history = SerialHistory.new(zone, 3001, dns_records)
        server.add_conditional_action(caf.zone_load(serial_history))
        server.start.wait_until_ready

        client = TCPSocket.new('localhost', options[:port])
        message = MB.axfr_request(zone)
        wire_data = MessageHelper.tcp_message_package_for_write(message)
        client.write(wire_data)
        response, _ = MessageHelper.read_tcp_message(client)

        answers = response.answer.to_a
        check_soa = check_soa_fn(answers, zone)
        check_a   = check_a_fn(answers, 'x.ruby-lang.org')

        check_soa.(0, 3001)
        check_a.(1, '1.1.1.2')
        check_a.(2, '1.1.1.3')
        check_soa.(3, 3001)
      end
    end


    it 'should return an IXFR response correctly' do

      zone = 'ruby-lang.org'

      serial_history = ->() do
        history = SerialHistory.new(zone, 3001)
        history.set_serial_additions(3002, MB.rr('A', 'x.ruby-lang.org', '1.1.1.2'))
        history.set_serial_additions(3003, MB.rr('A', 'x.ruby-lang.org', '1.1.1.3'))
        history.set_serial_additions(3004, MB.rr('A', 'x.ruby-lang.org', '1.1.1.4'))
        history.set_serial_deletions(3004, MB.rr('A', 'x.ruby-lang.org', '1.1.1.2'))
        history.set_serial_additions(3005, MB.rr('A', 'x.ruby-lang.org', '1.1.1.5'))
        history
      end

      Server.with_new_server(options) do |server|

        server.add_conditional_action(caf.zone_load(serial_history.()))
        server.start.wait_until_ready

        # Can put a pry here and then:
        # .dig -p 9999 @127.0.0.1 ruby-lang.org ixfr=3003

        client = TCPSocket.new('localhost', options[:port])
        query = MB.ixfr_request(zone, 3003)
        wire_data = MessageHelper.tcp_message_package_for_write(query)
        client.write(wire_data)
        response, _ = MessageHelper.read_tcp_message(client)
        #puts `dig -p 9999 @127.0.0.1 ruby-lang.org ixfr=3001 2>&1`

        expect(response).to be_a(Dnsruby::Message)

        answers = response.answer.to_a

        check_soa = check_soa_fn(answers, zone)
        check_a   = check_a_fn(answers, 'x.ruby-lang.org')

        check_soa.(0, 3005)

        check_soa.(1, 3003)
        check_a.(2, '1.1.1.2')

        check_soa.(3, 3004)
        check_a.(4, '1.1.1.4')

        check_soa.(5, 3004)

        check_soa.(6, 3005)
        check_a.(7, '1.1.1.5')

        check_soa.(8, 3005)
      end
    end


    it 'servers work when there are multiple servers running' do
      begin
        ports = [9998, 9999]
        servers = ports.map { |port| Server.new(options.merge(port: port)) }
        servers.each do |server|
          serial = server.port # for convenience, use server's port as the serial
          server.add_conditional_action(caf.soa_response(serial, 'com'))
          server.start.wait_until_ready
        end

        servers.each do |server|
          request = MB.soa_request('com')
          response = MessageHelper.send_udp_and_get_response(request, host, server.port)
          expect(MessageTransformer.new(response).serial).to eq(server.port)
        end

      ensure
        if servers
          servers.each { |server| server.close }
        end
      end
    end


    it 'can close multiple times without error' do
      expect(->() { Server.with_new_server(options) do |server|
        server.close
        server.close
      end }).not_to raise_error
    end


    it 'will not allow starting a server (and spawning a new thread) more than once' do
      test_lambda = ->() do
        Server.with_new_server(options) do |server|
          server.start.wait_until_ready
          server.start
        end
      end
      expect(test_lambda).to raise_error
    end


    it 'kill_all_servers works' do

      Server.kill_all_servers  # make sure we're starting with zero servers
      ports = [9998, 9999]
      servers = ports.map { |port| Server.new(options.merge({ port: port }))}

      servers.each do |server|
        # for convenience, use server's port as the serial
        server.add_conditional_action(caf.soa_response(1001, 'com'))
        server.start.wait_until_ready
      end

      expect(servers.size).to eq(2)
      expect(ServerThread.all.size).to eq(2)
      Server.kill_all_servers
      sleep 1
      expect(ServerThread.all.size).to eq(0)
    end
  end
end

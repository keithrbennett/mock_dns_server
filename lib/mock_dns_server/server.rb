require 'socket'
require 'forwardable'
require 'thread_safe'

require 'mock_dns_server/message_helper'
require 'mock_dns_server/server_context'
require 'mock_dns_server/server_thread'


module MockDnsServer

  # Starts a UDP and TCP server that listens for DNS and/or other messages.
  class Server

    extend Forwardable
    def_delegators :@context, :host, :port, :conditional_actions, :timeout_secs, :verbose

# Do we want serials to be attributes of the server, or configured in conditional actions?

    attr_reader :context, :sockets, :serials, :control_queue

    DEFAULT_PORT = 53
    DEFAULT_TIMEOUT = 1.0


    def initialize(options = {})

      @closed = false
      defaults = {
          port: DEFAULT_PORT,
          timeout_secs: DEFAULT_TIMEOUT,
          verbose: false
      }
      options = defaults.merge(options)

      @context = ServerContext.new(self, options)

      self.class.open_servers << self
      create_sockets
    end


    # Creates a server, executes the passed block, and then closes the server.
    def create_sockets
      @tcp_listener_socket = TCPServer.new(host, port)
      @tcp_listener_socket.setsockopt(:SOCKET, :REUSEADDR, true)

      @udp_socket = UDPSocket.new
      @udp_socket.bind(host, port)

      @control_queue = SizedQueue.new(1000)

      @sockets = [@tcp_listener_socket, @udp_socket]
    end


    # Closes the sockets and exits the server thread if it has already been created.
    def close
      return if closed?
      puts "Closing #{self}..." if verbose
      @closed = true

      sockets.each { |socket| socket.close unless socket.closed? }

      self.class.open_servers.delete(self)

      if @server_thread
        @server_thread.exit
        @server_thread.join
        @server_thread = nil
      end
    end


    def closed?
      @closed
    end


    # Determines whether the server has reached the point in its lifetime when it is ready,
    # but it may still be true after the server is closed.  Intended to be used during server
    # startup and not thereafter.
    def ready?
      !! @ready
    end


    def add_conditional_action(conditional_action)
      conditional_actions.add(conditional_action)
    end


    def add_conditional_actions(conditional_actions)
      conditional_actions.each { |ca| add_conditional_action(ca) }
    end


    def record_receipt(request, sender, protocol)
      history.add_incoming(request, sender, protocol)
    end


    def handle_request(request, sender, protocol)

      request = MessageHelper.to_dns_message(request)

      context.with_mutex do
        if block_given?
          yield(request, sender, protocol)
        else
          record_receipt(request, sender, protocol)
          context.conditional_actions.respond_to(request, sender, protocol)
        end
      end
    end


    def conditional_action_count
      context.conditional_actions.size
    end


    # Starts this server and returns the new thread in which it will run.
    # If a block is passed, it will be passed in turn to handle_request
    # to be executed (on the server's thread).
    def start(&block)
      raise "Server already started." if @server_thread

      puts "Starting server on host #{host}:#{port}..." if verbose
      @server_thread = ServerThread.new do
        begin

          Thread.current.server = self

          loop do
            unless @control_queue.empty?
              action = @control_queue.pop
              action.()
            end

            @ready = true
            reads, _, errors = IO.select(sockets, nil, sockets, timeout_secs)

            error_occurred = errors && errors.first  # errors.first will be nil on timeout
            if error_occurred
              puts errors if verbose
              break
            end

            if reads
              reads.each do |read_socket|
                handle_read(block, read_socket)
                #if conditional_actions.empty?
                #  puts "No more conditional actions.  Closing server..." if verbose
                #  break
                #end
              end
            else
              # TODO: This is where we can put things to do periodically when the server is not busy
            end
          end
        rescue => e
          self.close
          # Errno::EBADF is raised when the server object is closed normally,
          # so we don't want to report it.  All other errors should be reported.
          raise e unless e.is_a?(Errno::EBADF)
        end
      end
      self  # for chaining, especially with wait_until_ready
    end


    # Handles the receiving of a single message.
    def handle_read(block, read_socket)

      request = nil
      sender = nil
      protocol = nil

      if read_socket == @tcp_listener_socket
        sockets << @tcp_listener_socket.accept
        puts "Got new TCP socket: #{sockets.last}" if verbose

      elsif read_socket == @udp_socket
        protocol = :udp
        request, sender = udp_recvfrom_with_timeout(read_socket)
        request = MessageHelper.to_dns_message(request)
        puts "Got incoming message from UDP socket:\n#{request}\n" if verbose

      else # it must be a spawned TCP read socket
        if read_socket.eof? # we're here because it closed on the client side
          sockets.delete(read_socket)
          puts "received EOF from socket #{read_socket}...deleted it from listener list." if verbose
        else # read from it
          protocol = :tcp

          # Read message size:
          request = MessageHelper.read_tcp_message(read_socket)
          sender = read_socket

          if verbose
            if request.nil? || request == ''
              puts "Got no request."
            else
              puts "Got incoming message from TCP socket:\n#{request}\n"
            end
          end
        end
      end
      handle_request(request, sender, protocol, &block) if request
    end


    def send_tcp_response(socket, content)
      socket.write(MessageHelper.tcp_message_package_for_write(content))
    end


    def send_udp_response(sender, content)
      send_data = MessageHelper.udp_message_package_for_write(content)
      _, client_port, ip_addr, _ = sender
      @udp_socket.send(send_data, 0, ip_addr, client_port)
    end


    def send_response(sender, content, protocol)
      if protocol == :tcp
        send_tcp_response(sender, content)
      elsif protocol == :udp
        send_udp_response(sender, content)
      end
    end


    def history_copy
      copy = nil
      context.with_mutex { copy = history.copy }
      copy
    end


    def history
      context.history
    end; private :history


    def occurred?(inspection)
      history.occurred?(inspection)
    end


    def conditional_actions
      context.conditional_actions
    end; private :conditional_actions


    def is_dns_packet?(packet, protocol)
      raise "protocol must be :tcp or :udp" unless [:tcp, :udp].include?(protocol)

      encoded_message = :udp ? packet : packet[2..-1]
      message = MessageHelper.to_dns_message(encoded_message)
      message.is_a?(Dnsruby::Message)
    end


    # @param message_options - name (zone), serial, mname
    def send_notify(zts_host, zts_port, message_options, notify_message_override = nil, wait_for_response = true)
      notify_message = notify_message_override ? notify_message_override : MessageBuilder::notify_message(message_options)

      socket = UDPSocket.new

      puts "Sending notify message to host #{zts_host}, port #{zts_port}" if verbose
      socket.send(notify_message.encode, 0, zts_host, zts_port)

      if wait_for_response
        response_wire_data, _ = udp_recvfrom_with_timeout(socket)
        response = MessageHelper.to_dns_message(response_wire_data)
        context.with_mutex { history.add_notify_response(response, zts_host, zts_port, :udp) }
        response
      else
        nil
      end
    end


    def udp_recvfrom_with_timeout(udp_socket, timeout_secs = 10, max_data_size = 10_000) # TODO: better default max?
      request = nil
      sender = nil

      recv_thread = Thread.new do
        request, sender = udp_socket.recvfrom(max_data_size)
      end
      timeout_expired = recv_thread.join(timeout_secs).nil?
      if timeout_expired
        recv_thread.exit
        raise "Response not received from UDP socket."
      end
      [request, sender]
    end

    # For an already initialized server, perform the passed block and ensure that the server
    # will be closed, even if an error is raised.
    def do_then_close
      begin
        start
        yield
      ensure
        close
      end
    end


    # Waits until the server is ready, sleeping between calls to ready.
    # @return elapsed time until ready
    def wait_until_ready(sleep_duration = 0.000_02)

      if Thread.current == @server_thread
        raise "This method must not be called in the server's thread."
      end

      start = Time.now
      sleep(sleep_duration) until ready?
      duration = Time.now - start
      duration
    end


    # Sets up the SOA and records to serve on IXFR/AXFR queries.
    # mname is set to "default.#{zone}
    #
    # @param options hash containing the following keys:
    #  zone
    #  serial (SOA)
    #  dns_records  array of RR's
    #  times  times for the action to be performed before removal (optional, defaults to forever)
    #  zts_hosts  array of ZTS hosts
    #  zts_port (optional, defaults to 53)
    #
    def load_zone(options)

      validate_options = ->() do
        required_options = [:zone, :serial_history]
        missing_options = required_options.select { |o| options[o].nil? }
        unless missing_options.empty?
          raise "Options required for load_zone were missing: #{missing_options.join(', ')}."
        end
      end

      validate_options.()

      serial_history = options[:serial_history]
      zone           = serial_history.zone
      zts_hosts      = Array(options[:zts_hosts])
      zts_port       = options[:zts_port] || 53
      times          = options[:times] || 0
      mname          = "default.#{zone}"

      cond_action = ConditionalActionFactory.new.zone_load(serial_history, times)
      conditional_actions.add(cond_action)

      notify_options = { name: zone, serial: serial_history.high_serial, mname: mname }
      zts_hosts.each do |zts_host|
        send_notify(zts_host, zts_port, notify_options)
      end
    end


    def to_s
      "#{self.class.name}: host: #{host}, port: #{port}, ready: #{ready?}, closed: #{closed?}"
    end


    def self.open_servers
      @servers ||= ThreadSafe::Array.new
    end


    # Creates a new server, yields to the passed block, then closes the server.
    def self.with_new_server(options = {})
      begin
        server = self.new(options)
        yield(server)
      ensure
        server.close if server
      end
      nil  # don't want to return server because it should no longer be used
    end


    def self.close_all_servers
      open_servers.clone.each { |server| server.close }
    end


    def self.kill_all_servers
      threads_needing_exit = ServerThread.all.select { |thread| ['sleep', 'run'].include?(thread.status) }

      threads_needing_exit.each do |thread|
        server = thread.server
        # If we can get a handle on the server, close it; else, just exit the thread.
        if server
          server.close
          raise "Sockets not closed." unless server.closed?
        else
          raise "Could not get server reference"
        end
        thread.join
      end
    end


    # Returns the IP addresses (as strings) of the host on which this is running
    # that are eligible to be used for a Server instance.  Eligibility is defined
    # as IPV4, not loopback, and not multicast.
    def self.eligible_interfaces
      addrinfos = Socket.ip_address_list.select do |intf|
        intf.ipv4? && !intf.ipv4_loopback? && !intf.ipv4_multicast?
      end
      addrinfos.map(&:ip_address)
    end
  end
end

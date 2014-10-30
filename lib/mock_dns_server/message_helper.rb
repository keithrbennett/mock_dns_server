
module MockDnsServer

  module MessageHelper

    MESSAGE_LENGTH_PACK_UNPACK_FORMAT = 'n'

    # If the string can convert to a Dnsruby::Message without throwing an exception,
    # return the Dnsruby::Message instance; else, return the original string.
    def self.to_dns_message(object)
      case object
        when String
          begin
            Dnsruby::Message.decode(object)
          rescue
            object
          end
        when Dnsruby::Message
          object
      end
    end


    def self.convertible_to_dnsruby_message?(object)
      to_dns_message(object).is_a?(Dnsruby::Message)
    end



    # Builds a string for a TCP client to send to a DNS server
    #
    # @param message, either a DNS message or a string
    # @return if message is a Dnsruby::Message, returns the wire_data prepended with the 2-byte size field
    #        else returns the message unchanged
    def self.tcp_message_package_for_write(message)
      message = message.encode if message.is_a?(Dnsruby::Message)
      size_field = [message.size].pack(MESSAGE_LENGTH_PACK_UNPACK_FORMAT)
      size_field + message
    end


    def self.udp_message_package_for_write(object)
      case object
        when Dnsruby::Message
          object.encode
        when String
          object
      end
    end


    # Reads a message from a TCP connection.  First gets the 2 byte length, then reads the payload.
    # Attempts to convert the payload into a Dnsruby::Message.
    def self.read_tcp_message(socket)

      message_len_str = socket.read(2)
      raise "Unable to read from socket; read returned nil" if message_len_str.nil?
      message_len = message_len_str.unpack(MESSAGE_LENGTH_PACK_UNPACK_FORMAT).first

      bytes_not_yet_read = message_len
      message_wire_data = ''

      while bytes_not_yet_read > 0
        str = socket.read(bytes_not_yet_read)
        bytes_not_yet_read -= str.size
        message_wire_data << str
      end

      message = MessageHelper.to_dns_message(message_wire_data)
      message
    end


    # Sends a UDP message and returns the response, using a temporary socket.
    def self.send_udp_and_get_response(message, host, port)
      socket = UDPSocket.new
      message = message.encode if message.is_a?(Dnsruby::Message)
      socket.send(message, 0, host, port)
      _, _, _ = IO.select([socket], nil, nil)
      response_data, _ = socket.recvfrom(10_000)
      response = to_dns_message(response_data)
      socket.close
      response
    end
  end
end

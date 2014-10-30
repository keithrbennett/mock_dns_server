require 'mock_dns_server/message_builder'

module MockDnsServer

# Creates and returns actions that will be run upon receiving incoming messages.
class ActionFactory

  include MessageBuilder

  # Echos the request back to the sender.
  def echo
    ->(incoming_message, sender, context, protocol) do
      context.server.send_response(sender, incoming_message, protocol)
    end
  end

  def puts_and_echo
    ->(incoming_message, sender, context, protocol) do
      puts "Received #{protocol.to_s.upcase} message from #{sender}:\n#{incoming_message}\n\n"
      puts "Hex:\n\n"
      puts "#{incoming_message.encode.hexdump}\n\n"
      echo.(incoming_message, sender, context, protocol)
    end
  end

  # Responds with the same object regardless of the request content.
  def constant(constant_object)
    ->(_, sender, context, protocol) do
      context.server.send_response(sender, constant_object, protocol)
    end
  end


  # Sends a SOA response.
  def send_soa(zone, serial, expire = nil, refresh = nil)
    send_message(soa_response(
        name: zone, serial: serial, expire: expire, refresh: refresh))
  end


  # Sends a fixed DNSRuby::Message.
  def send_message(response)
    ->(incoming_message, sender, context, protocol) do

      if [incoming_message, response].all? { |m| m.is_a?(Dnsruby::Message) }
        response.header.id = incoming_message.header.id
      end
      if response.is_a?(Dnsruby::Message)
        response.header.qr = true
      end
      context.server.send_response(sender, response, protocol)
    end
  end

  # Outputs the string representation of the incoming message to stdout.
  def puts_message
    ->(incoming_message, sender, context, protocol) do
      puts incoming_message
    end
  end


  def zone_load(serial_history)
    ->(incoming_message, sender, context, protocol) do

      mt = MessageTransformer.new(incoming_message)
      zone = mt.qname
      type = mt.qtype

      if serial_history.zone.downcase != zone.downcase
        raise "Zones differ (history: #{serial_history.zone}, request: #{zone}"
      end

      if %w(AXFR IXFR).include?(type)
        xfr_response = serial_history.xfr_response(incoming_message)
        send_message(xfr_response).(incoming_message, sender, context, :tcp)
      elsif type == 'SOA'
        send_soa(zone, serial_history.high_serial).(incoming_message, sender, context, protocol)
      end
    end
  end

end
end

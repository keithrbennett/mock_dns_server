require 'ipaddr'

require 'dnsruby'
require 'mock_dns_server/dnsruby_monkey_patch'
require 'mock_dns_server/ip_address_dispenser'
require 'mock_dns_server/serial_number'

module MockDnsServer

module MessageBuilder

  module_function

  #def soa_response(zone, serial, expire = nil, refresh = nil)
  #
  #  options = {
  #      type: 'SOA', klass: 'IN', name: zone, ttl: 3600, serial: serial
  #  }
  #  options[:refresh] = refresh if refresh
  #  options[:expire]  = expire  if expire
  #
  #
  #  response = Dnsruby::Message.new
  #
  #  answer = Dnsruby::RR.new_from_hash(options)
  #  response.add_answer(answer)
  #
  #  response
  #
  #  Additional options:
  #  @mname = Name.create(hash[:mname])
  #  @rname = Name.create(hash[:rname])
  #  @serial = hash[:serial].to_i
  #  @refresh = hash[:refresh].to_i
  #  @retry = hash[:retry].to_i
  #  @expire = hash[:expire].to_i
  #  @minimum = hash[:minimum].to_i
  #end


  # Builds a response to an 'A' request from the encoded string passed.
  # @param answer_string string in any format supported by Dnsruby::RR.create
  # (see resource.rb, e.g. https://github.com/vertis/dnsruby/blob/master/lib/Dnsruby/resource/resource.rb,
  # line 643 ff at the time of this writing):
  #
  #   a     = Dnsruby::RR.create("foo.example.com. 86400 A 10.1.2.3")
  def specified_a_response(answer_string)
    message = Dnsruby::Message.new
    message.header.qr = true
    answer = Dnsruby::RR.create(answer_string)
    message.add_answer(answer)
    message
  end


  def dummy_a_response(record_count, domain, ttl = 86400)
    ip_dispenser = IpAddressDispenser.new
    message = Dnsruby::Message.new
    message.header.qr = true

    record_count.times do
      answer = Dnsruby::RR.new_from_hash(
          name: domain, ttl: ttl, type: 'A', address: ip_dispenser.next, klass: 'IN')
      message.add_answer(answer)
    end
    message
  end


  # Gets the serial value from the passed object; if it's a SerialNumber,
  # calls its value method; if not, we assume it's a number and it's returned unchanged.
  def serial_value(serial)
    serial.is_a?(SerialNumber) ? serial.value : serial
  end


  def soa_request(name)
    Dnsruby::Message.new(name, 'SOA', 'IN')
  end


  def soa_answer(options)
    mname = options[:mname] || 'default.com'

    Dnsruby::RR.create( {
      name:    options[:name],
      ttl:     options[:ttl] || 3600,
      type:    'SOA',
      serial:  serial_value(options[:serial]),
      mname:   mname,
      rname:   'admin.' + mname,
      refresh: options[:refresh] || 3600,
      retry:   options[:retry]   || 3600,
      expire:  options[:expire]  || 3600,
      minimum: options[:minimum] || 3600
    } )
  end


  # Builds a Dnsruby::RR instance with the specified type, name, and rdata,
  # with a hard coded TTL and class 'IN'.
  def rr(type, name, rdata)
    ttl = 3600
    klass = 'IN'
    string = [name, ttl, klass, type, rdata].join(' ')
    Dnsruby::RR.new_from_string(string)
  end


  # Creates an NS RR record.
  def ns(owner, address)
    rr('NS', owner, address)
  end


  # Creates a Dnsruby::Update object from a hash,
  # as it would be generated from a Cucumber table
  # with the following headings:
  # | Action | Type | Domain      | RDATA  |
  def dns_update(zone, records)
    update = Dnsruby::Update.new(zone)
    records.each do |r|
      if r.type.upcase == 'ADD'
        s = "#{Domain} 3600 #{Type}  #{RDATA}"
        rr = Dnsruby::RR.create(s)
        update.add(rr)
      else
        update.delete(r['Domain'], r['Type'], r['RDATA'])
      end
    end
    update
  end


  # @param options a hash containing values for keys [:name, :serial, :mname]
  # TODO: Eliminate duplication of soa_response and notify_message
  def soa_response(options)
    raise "Must provide zone name as options[:name]." if options[:name].nil?
    message = Dnsruby::Message.new(options[:name], 'SOA', 'IN')
    message.header.qr = true
    message.add_answer(soa_answer(options))
    message
  end


  # Builds a SOA RR suitable for inclusion in the authority section of an IXFR query.
  def ixfr_request_soa_rr(zone, serial)
    options = {
        name: zone,
        type: 'SOA',
        ttl: 3600,
        klass: 'IN',
        mname: '.',
        rname: '.',
        serial: serial_value(serial),
        refresh: 0,
        retry: 0,
        expire: 0,
        minimum: 0
    }

    Dnsruby::RR.new_from_hash(options)
  end


  def ixfr_request(zone, serial)
    query = Dnsruby::Message.new(zone, 'IXFR')
    query.add_authority(ixfr_request_soa_rr(zone, serial_value(serial)))
    query
  end


  def axfr_request(zone)
    Dnsruby::Message.new(zone, 'AXFR')
  end

  # @param options a hash containing values for keys [:name, :serial, :mname]
  def notify_message(options)

    message = Dnsruby::Message.new(options[:name], 'SOA', 'IN')
    message.header.opcode = Dnsruby::OpCode::Notify

    mname = options[:mname] || 'default.com'

    message.add_answer(Dnsruby::RR.new_from_hash( {
        name:    options[:name],
        type:    'SOA',
        serial:  serial_value(options[:serial]),
        mname:   mname,
        rname:   'admin.' + mname,
        refresh: 3600,
        retry:   3600,
        expire:  3600,
        minimum: 3600
    } ))
    message
  end
end
end

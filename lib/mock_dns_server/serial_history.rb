require 'thread_safe'
require 'mock_dns_server/serial_transaction'

module MockDnsServer

# Manages RR additions and deletions for multiple serials,
# and builds responses to AXFR and IXFR requests.
class SerialHistory

  attr_accessor :zone, :low_serial, :ixfr_response_uses_axfr_style

  # Creates the instance.
  # @param zone
  # @param start_serial the serial of the data set provided in the initial_records
  # @param initial_records the starting data
  # @param ixfr_response_uses_axfr_style when to respond to an IXFR request with an AXFR-style IXFR,
  #            rather than an IXFR list of changes.  Regardless of this option,
  #            if the requested serial >= the last known serial of this history,
  #            a response with a single SOA record containing the highest known serial will be sent.
  #            The following options apply to any other case, and are:
  #
  #           :never (default) - always return IXFR-style, but
  #               if the requested serial is not known by the server
  #               (i.e. if it is *not* the serial of one of the transactions in the history),
  #               then return 'transfer failed' rcode
  #           :always - always return AXFR-style
  #           :auto - if the requested serial is known by the server (i.e. if it is
  #                the serial of one of the transactions in the history,
  #                or is the initial serial of the history), then return an IXFR list;
  #                otherwise return an AXFR list.
  #           Note that even when an AXFR-style list is returned, it is still an IXFR
  #           response -- that is, the IXFR question from the query is copied into the response.
  def initialize(zone, start_serial, initial_records = [], ixfr_response_uses_axfr_style = :never)
    @zone = zone
    @low_serial = SerialNumber.object(start_serial)
    @initial_records = initial_records
    self.ixfr_response_uses_axfr_style = ixfr_response_uses_axfr_style
    @txns = ThreadSafe::Hash.new  # txns is an abbreviation of transactions
  end

  def ixfr_response_uses_axfr_style=(mode)

    validate_input = ->() do
      valid_modes = [:never, :always, :auto]
      unless valid_modes.include?(mode)
        valid_modes_as_string = valid_modes.map(&:inspect).join(', ')
        raise "ixfr_response_uses_axfr_style mode must be one of the following: #{valid_modes_as_string}"
      end
    end

    validate_input.()
    @ixfr_response_uses_axfr_style = mode
  end

  def set_serial_additions(serial, additions)
    serial = SerialNumber.object(serial)
    additions = Array(additions)
    serial_transaction(serial).additions = additions
    self
  end

  def serial_additions(serial)
    serial = SerialNumber.object(serial)
    @txns[serial] ? @txns[serial].additions : nil
  end

  def set_serial_deletions(serial, deletions)
    serial = SerialNumber.object(serial)
    deletions = Array(deletions)
    serial_transaction(serial).deletions = deletions
    self
  end

  def serial_deletions(serial)
    serial = SerialNumber.object(serial)
    @txns[serial] ? @txns[serial].deletions : nil
  end

  def txn_serials
    @txns.keys
  end

  def serials
    [low_serial] + txn_serials
  end

  def high_serial
    txn_serials.empty? ? low_serial : txn_serials.last
  end

  def to_s
    "#{self.class.name}: zone: #{zone}, initial serial: #{low_serial}, high_serial: #{high_serial}, records:\n#{ixfr_records}\n"
  end

  # Although Dnsruby has a <=> operator on RR's, we need a comparison that looks only
  # at the type, name, and rdata (and not the TTL, for example), for purposes of
  # detecting records that need be deleted.
  def rr_compare(rr1, rr2)

    rrs = [rr1, rr2]

    name1, name2 = rrs.map { |rr| rr.name.to_s.downcase }
    if name1 != name2
      return name1 > name2 ? 1 : -1
    end

    type1, type2 = rrs.map { |rr| rr.type.to_s.downcase }
    if type1 != type2
      return type1 > type2 ? 1 : -1
    end

    rdata1, rdata2 = rrs.map(&:rdata)
    if rdata1 != rdata2
      rdata1 > rdata2 ? 1 : -1
    else
      0
    end
  end


  def rr_equivalent(rr1, rr2)
    rr_compare(rr1, rr2) == 0
  end


  # @return a snapshot array of the data as of a given serial number
  # @serial if a number, must be in the range of known serials
  #         if :current, the highest known serial will be used
  def data_at_serial(serial)

    serial = high_serial if serial == :current
    serial = SerialNumber.object(serial)

    if serial.nil? || serial > high_serial || serial < low_serial
      raise "Serial must be in range #{low_serial} to #{high_serial} inclusive."
    end
    data = @initial_records.clone

    txn_serials.each do |key|
      txn = @txns[key]
      break if txn.serial > serial
      txn.deletions.each do |d|
        data.reject! { |rr| rr_equivalent(rr, d) }
      end
      txn.additions.each do |a|
        data.reject! { |rr| rr_equivalent(rr, a) }
        data << a
      end
    end

    data
  end

  def current_data
    data_at_serial(:current)
  end

  def high_serial_soa_rr
    MessageBuilder.soa_answer(name: zone, serial: high_serial)
  end

  def axfr_records
    [high_serial_soa_rr, current_data, high_serial_soa_rr].flatten
  end


  # Finds the serial previous to that of this transaction.
  # @return If txn is the first txn, returns start_serial of the history
  # else the serial of the previous transaction
  def previous_serial(serial)
    serial = SerialNumber.object(serial)
    return nil if serial <= low_serial || serial > high_serial

    txn_index = txn_serials.find_index(serial)
    txn_index > 0 ? txn_serials[txn_index - 1] : @low_serial
  end


  # @return an array of RR's that can be used to populate an IXFR response.
  # @base_serial the serial from which to start when building the list of changes
  def ixfr_records(base_serial = nil)
    base_serial = SerialNumber.object(base_serial)

    records = []
    records << high_serial_soa_rr

    serials = @txns.keys

    # Note that the serials in the data structure are the 'to' serials,
    # whereas the serial of this request will be the 'from' serial.
    # To compensate for this, we take the first serial *after* the
    # occurrence of base_serial in the array of serials, thus the +1 below.
    index_minus_one = serials.find_index(base_serial)
    index_is_index_other_than_last_index = index_minus_one && index_minus_one < serials.size - 1

    base_serial_index = index_is_index_other_than_last_index ? index_minus_one + 1 : 0

    serials_to_process = serials[base_serial_index..-1]
    serials_to_process.each do |serial|
      txn = @txns[serial]
      txn_records = txn.ixfr_records(previous_serial(serial))
      txn_records.each { |rec| records << rec }
    end

    records << high_serial_soa_rr
    records
  end


  # Determines whether a given record array is AXFR- or IXFR-style.
  # @param records array of IXFR or AXFR records
  # @return :ixfr, :axfr, :error
  def xfr_array_type(records)
    begin
      for num_consecutive_soas in (0..records.size)
        break unless records[num_consecutive_soas].is_a?(Dnsruby::RR::SOA)
      end
      case num_consecutive_soas
        when nil; :error
        when 0;   :error
        when 1;   :axfr
        else;     :ixfr
      end
    rescue => e
      :error
    end
  end


  def is_tracked_serial(serial)
    serial = SerialNumber.object(serial)
    serials.include?(serial)
  end


  # Returns the next serial value that could be added to the history,
  # i.e. the successor to the highest serial we now have.
  def next_serial_value
    SerialNumber.next_serial_value(high_serial.to_i)
  end


  # When handling an IXFR request, use the following logic:
  #
  # if the serial number requested >= the current serial number (highest_serial),
  # return a single SOA record (at the current serial number).
  #
  # Otherwise, given the current value of ixfr_response_uses_axfr_style:
  #
  # :always - always return an AXFR-style IXFR response
  #
  # :never (default) - if we have that serial in our history, return an IXFR response,
  #                    else return a Transfer Failed error message
  #
  # :auto - if we have that serial in our history, return an IXFR response,
  #         else return an AXFR style response.
  #
  # @return the type of response appropriate to this serial and request
  def ixfr_response_style(serial)
    serial = SerialNumber.object(serial)

    if serial >= high_serial
      :single_soa
    else
      case ixfr_response_uses_axfr_style
        when :never
          is_tracked_serial(serial) ? :ixfr : :xfer_failed
        when :auto
          is_tracked_serial(serial) ? :ixfr : :axfr_style_ixfr
        when :always
          :axfr_style_ixfr
      end
    end
  end


  # Creates a response message based on the type and serial of the incoming message.
  # @param incoming_message an AXFR or IXFR request
  # @return a Dnsruby message containing the response, either or AXFR or IXFR
  def xfr_response(incoming_message)

    mt           = MessageTransformer.new(incoming_message)
    query_zone   = mt.qname
    query_type   = mt.qtype.downcase.to_sym  # :axfr or :ixfr
    query_serial = mt.serial(:authority)  # ixfr requests only, else will be nil

    validate_inputs = ->() {
      if query_zone.downcase != zone.downcase
        raise "Query zone (#{query_zone}) differs from history zone (#{zone})."
      end

      unless [:axfr, :ixfr].include?(query_type)
        raise "Invalid qtype (#{query_type}), must be AXFR or IXFR."
      end

      if query_type == :ixfr && query_serial.nil?
        raise 'IXFR request did not specify serial in authority section.'
      end
    }

    build_standard_response = ->(rrs = nil) do
      response = Dnsruby::Message.new
      response.header.qr = true
      response.header.aa = true
      rrs.each { |record| response.add_answer!(record) } if rrs
      incoming_message.question.each { |q| response.add_question(q) }
      response
    end

    build_error_response = ->() {
      response = build_standard_response.()
      response.header.rcode = Dnsruby::RCode::REFUSED
      response
    }

    build_single_soa_response = ->() {
      build_standard_response.([high_serial_soa_rr])
    }

    validate_inputs.()
    xfr_response = nil

    case query_type

      when :axfr
        xfr_response = build_standard_response.(axfr_records)
      when :ixfr
        response_style = ixfr_response_style(query_serial)

        case response_style
          when :axfr_style_ixfr
            xfr_response = build_standard_response.(axfr_records)
          when :ixfr
            xfr_response = build_standard_response.(ixfr_records(query_serial))
          when :single_soa
            xfr_response = build_single_soa_response.()
          when :error
            xfr_response = build_error_response.()
        end
    end

  xfr_response
  end

  private

  # Checks to see that a new serial whose transactions will be added to the history
  # has a valid serial value in the context of the data already there.
  # Raises an error if the serial is bad, else does nothing.
  def check_new_serial(new_serial)
    if new_serial < low_serial
      raise "New serial of #{new_serial} must not be lower than initial serial of #{low_serial}."
    elsif new_serial < high_serial
      raise "New serial of #{new_serial} must not be lower than highest preexisting serial of #{high_serial}."
    end
  end


  # Returns the SerialTransaction instance associated with this serial value,
  # creating it if it does not already exist.
  def serial_transaction(serial)
    unless @txns[serial]
      check_new_serial(serial)
      @txns[serial] ||= SerialTransaction.new(zone, serial)

      # As long as we prohibit adding serials out of order, there is no need for this:
      # recreate_hash
    end

    @txns[serial]
  end


  # Recreates the hash so that its keys are in ascending order.
  # Currently (12/18/2013) this is redundant, since serials must be added
  # in ascending order.
  #def recreate_hash
  #  keys = @txns.keys
  #  new_hash = ThreadSafe::Hash.new
  #  keys.sort.each { |key| new_hash[key] = @txns[key] }
  #  @txns = new_hash
  #end

end
end

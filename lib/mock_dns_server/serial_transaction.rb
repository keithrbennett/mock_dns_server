module MockDnsServer

# Manages RR additions and deletions for a given serial.
class SerialTransaction

  # serial is the starting serial, i.e. the serial to which
  # the additions and changes will be applied to get to
  # the next serial value.
  attr_accessor :serial, :additions, :deletions, :zone

  # An object containing serial change information
  #
  # @param zone the zone for which this data applies
  # @param serial a number from 0 to 2^32 - 1, or a SerialNumber instance
  # @param deletions a single RR or an array of RR's representing deletions
  # @param additions a single RR or an array of RR's representing additions
  def initialize(zone, serial, deletions = [], additions = [])
    @zone = zone
    @serial = SerialNumber.object(serial)
    @deletions = Array(deletions)
    @additions = Array(additions)
  end


  # Returns an array of records corresponding to a serial change of 1,
  # including delimiting SOA records, suitable for inclusion in an
  # IXFR response.
  def ixfr_records(start_serial)
    records = []
    records << MessageBuilder.soa_answer(name: zone, serial: start_serial)
    deletions.each { |record| records << record }
    records << MessageBuilder.soa_answer(name: zone, serial: serial)
    additions.each { |record| records << record }
    #require 'awesome_print'; puts ''; ap records; puts ''
    records
  end


  def to_s
    s = "Changes to serial #{serial}:\n"
    deletions.each { |d| s << "- #{d}\n" }
    additions.each { |a| s << "+ #{a}\n" }
    s
  end
end
end

require 'ipaddr'
require 'dnsruby'

module MockDnsServer

# Wraps Ruby's IPAddr class and yields successive IP addresses.
# Instantiate it with a starting address (IPV4 or IPV6), and when
# you call .next, it will provide addresses that increment by 1
# or optional step parameter, starting with your initial address.
#
# We'll probably want to instruct it to be more intelligent, e.g. skip .0 and .255.
class IpAddressDispenser

  # @param initial_address first address dispensed, and basis for subsequent 'next' calls
  def initialize(initial_address = '192.168.1.1')
    @initial_address = initial_address
  end


  # @param step number of addresses to step in each next call, defaults to 1
  def next(step = 1)
    step.times do
      if @address.nil?
        @address = IPAddr.new(@initial_address)
      elsif @address.to_s == '255.255.255.255'
        @address = IPAddr.new('1.1.1.1')
      else
        @address = @address.succ
      end
    end
    @address.to_s
  end
end
end

require_relative '../spec_helper'

require 'mock_dns_server/ip_address_dispenser'

module MockDnsServer

describe IpAddressDispenser do

  it "should return the initial value when next is called for the first time" do
    expect(IpAddressDispenser.new('10.10.10.10').next.to_s).to eq('10.10.10.10')
  end

  it "should increment correctly in the least significant octet" do
    expect(IpAddressDispenser.new('10.10.10.10').next(2).to_s).to eq('10.10.10.11')
  end

  it "should roll over correctly in the 2 least significant octets" do
    expect(IpAddressDispenser.new('10.10.10.255').next(2).to_s).to eq('10.10.11.0')
  end

  it "should not raise an error and produces a valid IP address when called on 255.255.255.255" do
    new_address = IpAddressDispenser.new('255.255.255.255').next
    IPAddr.new(new_address)
  end

end
end

require 'rspec'

$LOAD_PATH << File.join(File.dirname(__FILE__), '..', '..', 'lib')

#class Object
#  def puts(s)
#    print "#{Thread.current}: #{s}\n"
#  end
#end

RSpec.configure do |config|

  config.expect_with :rspec do |c|
    # disable (forbid) the `should` syntax; it's deprecated and will later be removed
    c.syntax = :expect
  end
end


# Returns a function seeded with the specified record array and zone
# that can be used to test a given SOA RR and serial value.
def check_soa_fn(record_array, zone)
  ->(index, serial) do
    rr = record_array[index]
    expect(rr.class).to eq(Dnsruby::RR::IN::SOA)
    expect(rr.serial).to eq(serial)
    expect(rr.name.to_s).to eq(zone.to_s)
  end
end


# Returns a function seeded with the specified record array and name
# that can be used to test a given A RR and address.
def check_a_fn(record_array, name)
  ->(index, address) do
    rr = record_array[index]
    expect(rr.class).to eq(Dnsruby::RR::IN::A)
    expect(rr.name.to_s).to eq(name.to_s)
    expect(rr.address.to_s).to eq(address.to_s)
  end
end




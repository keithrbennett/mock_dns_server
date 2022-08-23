require_relative '../spec_helper'
require 'mock_dns_server/serial_number'

describe SerialNumber do

  SSS = SerialNumber


  context 'initial value validation' do

    def verify_init_error(value)
      expect { SerialNumber.new(value) }.to raise_error(RuntimeError)
    end

    def verify_init_ok(value)
      expect { SerialNumber.new(value) }.not_to raise_error(RuntimeError)
    end

    specify '-1 is not ok' do
      verify_init_error(-1)
    end

    specify '0 is ok' do
      verify_init_ok(0)
    end

    specify '1 is ok' do
      verify_init_ok(0)
    end

    specify '0xFFFF_FFFF is ok' do
      verify_init_ok(0xFFFF_FFFF)
    end

    specify '0x1_0000_0000 is not ok' do
      verify_init_error(0x1_0000_0000)
    end
  end

  context 'SequenceSpaceSerial#<=>' do

    specify '0 should == 0' do
      expect(SSS.new(0)).to eq(SSS.new(0))
    end

    specify '0 should < 0x7FFF_FFFF' do
      expect(SSS.new(0)).to be < SSS.new(0x7FFF_FFFF)
    end

    specify '0 <=> 0x8000_0000 should raise an error' do
      expect { SSS.new(0) <=> SSS.new(0x8000_0000) }.to raise_error(RuntimeError)
    end

    specify '0 should > 0x8000_0001' do
      expect(SSS.new(0)).to be > SSS.new(0x8000_0001)
    end

    specify '0xB000_0000 <=> 0xB000_0000 should == 0' do
      expect(SSS.new(0xB000_0000) <=> SSS.new(0xB000_0000)).to eq(0)
    end

    specify '0xB000_0000 should == 0xB000_0000' do
      expect(SSS.new(0xB000_0000)).to eq(SSS.new(0xB000_0000))
    end

    specify '0xB000_0000 should < 0x2FFF_FFFF' do
      expect(SSS.new(0xB000_0000)).to be < SSS.new(0x2FFF_FFFF)
    end

    specify '0xB000_0000 <=> 0x3000_0000 should raise an error' do
      expect { SSS.new(0xB000_0000) <=> SSS.new(0x3000_0000) }.to raise_error
    end

    specify '0xB000_0000 should > 0x3000_0001' do
      expect(SSS.new(0xB000_0000)).to be > SSS.new(0x3000_0001)
    end
  end


  context 'SequenceSpaceSerial.next_serial_value' do

    specify 'next of 0 to be 1' do
      expect(SSS.next_serial_value(0)).to eq(1)
    end

    specify 'next of -1 to raise error' do
      expect { SSS.next_serial_value(-1) }.to raise_error
    end

    specify 'next of 0x1_0000_0000 to raise error' do
      expect { SSS.next_serial_value(0x1_0000_0000) }.to raise_error
    end

    specify 'next of 0xFFFF_FFFF to be 0' do
      expect(SSS.next_serial_value(0xFFFF_FFFF)).to eq(0)
    end

    specify 'next of 0x1234_5678 to be 0x1234_5679' do
      expect(SSS.next_serial_value(0x1234_5678)).to eq(0x1234_5679)
    end

  end


  context 'SequenceSpaceSerial#next_serial' do

    specify 'next of 0 to be 1' do
      expect(SSS.new(0).next_serial).to eq(SSS.new(1))
    end

    specify 'next of 0xFFFF_FFFF to be 0' do
      expect(SSS.new(0xFFFF_FFFF).next_serial).to eq(SSS.new(0))
    end

    specify 'next of 0x1234_5678 to be 0x1234_5679' do
      expect(SSS.new(0x1234_5678).next_serial).to eq(SSS.new(0x1234_5679))
    end
  end
end

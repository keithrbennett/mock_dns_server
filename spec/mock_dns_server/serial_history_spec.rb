require 'spec_helper'
require 'mock_dns_server/serial_history'
require 'mock_dns_server/message_builder'

module MockDnsServer

describe SerialHistory do

  include MessageBuilder
  
  subject { SerialHistory.new('ruby-lang.org', 1001) }

  let(:rrs) do [
      rr('A', 'foo.ruby-lang.org', '1.2.3.4'),
      rr('A', 'foo.ruby-lang.org', '5.6.7.8')
  ] end

  # Note: the data intended to be stored is RR records,
  # but we're using Fixnum's to test the behavior.

  it 'adds additions to a serial' do
    subject.set_serial_additions(1111, [1, 2])
    expect(subject.serial_additions(1111)).to eq([1, 2])
  end

  it 'adds deletions to a serial' do
    subject.set_serial_deletions(2222, [3, 4])
    expect(subject.serial_deletions(2222)).to eq([3, 4])
  end


  # Test RR comparison that will be used for detecting records to delete.
  context "SerialHistory#rr_compare" do

    it 'returns correct values when comparing types' do
      rr1 = rr('A', 'abc.com', '1.2.3.4')
      rr2 = rr('NS', 'abc.com', '1.2.3.4')
      expect(subject.rr_compare(rr1, rr2) < 0).to be true
      expect(subject.rr_equivalent(rr1, rr2)).to be false
    end

    it 'returns correct values when comparing names' do
      rr1 = rr('A', 'abc.com', '1.2.3.4')
      rr2 = rr('A', 'nbc.com', '1.2.3.4')
      expect(subject.rr_compare(rr1, rr2) < 0).to be true
      expect(subject.rr_equivalent(rr1, rr2)).to be false
    end

    it 'returns correct values when comparing rdata' do
      rr1 = rr('A', 'abc.com', '1.2.3.4')
      rr2 = rr('A', 'abc.com', '2.2.3.4')
      expect(subject.rr_compare(rr1, rr2) < 0).to be true
      expect(subject.rr_equivalent(rr1, rr2)).to be false
    end

    it 'returns equal given 2 records with the same type, name, and rdata' do
      rr = rr('A', 'abc.com', '1.2.3.4')
      expect(subject.rr_compare(rr, rr)).to eq(0)
      expect(subject.rr_equivalent(rr, rr)).to be true
    end
  end


  context "SerialHistory#data_at_serial" do

    let (:history) do
      history = SerialHistory.new('ruby-lang.org', 1001)
      history.set_serial_additions(1002, rrs.first)
      history.set_serial_additions(1003, rrs.last)
      history
    end

    it 'removes records from the initial data correctly' do
      history = SerialHistory.new('ruby-lang.org', 1001, rrs)
      expect(history.data_at_serial(1001)).to eq(rrs)

      history.set_serial_deletions(1002, [rrs.first])
      history.serial_deletions(1002) << rrs.last
      expect(history.data_at_serial(1002)).to eq([])
    end

    it 'adds records to the initial data correctly' do
      history = SerialHistory.new('ruby-lang.org', 1001)
      expect(history.data_at_serial(1001)).to eq([])

      history.set_serial_additions(1002, [rrs.first])
      history.serial_additions(1002) << rrs.last
      expect(history.data_at_serial(1002)).to eq(rrs)
    end

    it 'accommodates a single RR instead of an array in the set methods' do
      history = SerialHistory.new('ruby-lang.org', 1001)

      history.set_serial_additions(1002, rrs.first)
      expect(history.data_at_serial(1002)).to eq([rrs.first])

      history.set_serial_deletions(1003, rrs.first)
      expect(history.data_at_serial(1003)).to eq([])
    end

    it 'does not include serials greater than requested' do
      history = SerialHistory.new('ruby-lang.org', 1001)
      history.set_serial_additions(1002, rrs.last)
      history.set_serial_additions(1003, rrs.first)
      expect(history.data_at_serial(1002)).to eq([rrs.last])
    end

    it 'includes all serials if data_at_serial is called with :current' do
      expect(history.data_at_serial(:current)).to eq(rrs)
    end

    it 'includes all serials when current_data is called' do
      expect(history.current_data).to eq(rrs)
    end

    it 'raises an error if the requested serial is too high' do
      expect(->() { history.data_at_serial(1004) }).to raise_error
    end

    it 'raises an error if the requested serial is too low' do
      expect(->() { history.data_at_serial(1000) }).to raise_error
    end

    it 'raises an error if the requested serial is nil' do
      expect(->() { history.data_at_serial(nil) }).to raise_error
    end
  end


  context 'SerialHistory#previous_serial' do

    let (:history) do
      history = SerialHistory.new('ruby-lang.org', 1001)
      history.set_serial_additions(1002, rrs.first)
      history.set_serial_additions(1003, rrs.last)
      history
    end

    it 'correctly finds the previous serial in the txns' do
      expect(history.previous_serial(1003).value).to eq(1002)
    end

    it 'correctly determines the previous serial when it is the initial serial' do
      expect(history.previous_serial(1002).value).to eq(1001)
    end

    it 'returns nil when passed the initial serial' do
      expect(history.previous_serial(1001)).to be_nil
    end

    it 'returns nil when passed a too-low serial' do
      expect(history.previous_serial(1000)).to be_nil
    end

    it 'returns nil when passed a too-high serial' do
      expect(history.previous_serial(1004)).to be_nil
    end
  end


  context "SerialHistory#ixfr_records" do

    let (:history) do
      history = SerialHistory.new('ruby-lang.org', 1001)
      history.set_serial_additions(1002, rrs.first)
      history.set_serial_additions(1003, rrs.last)
      history.set_serial_additions(1004, rr('A', 'foo.ruby-lang.org', '9.10.11.12'))
      history.set_serial_deletions(1004, rrs.first)
      history
    end

    it 'returns a correct set of records' do
      records = history.ixfr_records(1004)
      check_soa = check_soa_fn(records, 'ruby-lang.org')
      check_a   = check_a_fn(  records, 'foo.ruby-lang.org')

      check_soa.( 0, 1004)
      check_soa.( 1, 1001)
      check_soa.( 2, 1002)
      check_a.(   3, rrs.first.address)
      check_soa.( 4, 1002)
      check_soa.( 5, 1003)
      check_a.(   6, rrs.last.address)
      check_soa.( 7, 1003)
      check_a.(   8, rrs.first.address)
      check_soa.( 9, 1004)
      check_a.(  10, '9.10.11.12')
    end
  end


  context "SerialHistory#axfr_records" do

    let (:history) do
      history = SerialHistory.new('ruby-lang.org', 1001)
      history.set_serial_additions(1002, rrs.first)
      history.set_serial_additions(1003, rrs.last)
      history.set_serial_additions(1004, rr('A', 'foo.ruby-lang.org', '9.10.11.12'))
      history.set_serial_deletions(1004, rrs.first)
      history
    end

    it 'returns an AXFR record set if serial <= start_serial' do
      records = history.axfr_records

      check_soa = check_soa_fn(records, 'ruby-lang.org')
      check_a   = check_a_fn(  records, 'foo.ruby-lang.org')

      check_soa.(0, 1004)
      check_a.(  1, rrs.last.address)
      check_a.(  2, '9.10.11.12')
      check_soa.(3, 1004)
    end
  end


  context "SerialHistory#check_new_serial" do

    it 'raises an error if the new serial < the initial serial of the history' do
      history = SerialHistory.new('ruby-lang.org', 1001)
      expect(->() { history.check_serial(999) }).to raise_error
    end

    it 'raises an error if the new serial is not higher than the highest serial of the history' do
      history = SerialHistory.new('ruby-lang.org', 1001)
      history.set_serial_additions(1002, rrs.first)
      expect(->() { history.check_serial(1001) }).to raise_error
    end
  end


  context 'SerialHistory#xfr_array_type' do

    let (:history) do
      history = SerialHistory.new('ruby-lang.org', 1001)
      history.set_serial_additions(1002, rrs.first)
      history.set_serial_additions(1003, rrs.last)
      history.set_serial_additions(1004, rr('A', 'abc.ruby-lang.org', '9.10.11.12'))
      history.set_serial_deletions(1004, rrs.first)
      history
    end

    it 'should return :axfr for AXFR records' do
      expect(history.xfr_array_type(history.axfr_records)).to eq(:axfr)
    end

    it 'should return :ixfr for IXFR records' do
      expect(history.xfr_array_type(history.ixfr_records(1001))).to eq(:ixfr)
    end

    it 'should return :error for an empty array' do
      expect(history.xfr_array_type([])).to eq(:error)
    end
  end


  context 'SerialHistory#ixfr_response_style' do

    let(:zone) { 'ruby-lang.org' }
    let(:history) do
      h = SerialHistory.new(zone, 1111)
      h.set_serial_additions(1112, rr('A', 'abc.ruby-lang.org', '1.1.1.2'))
      h.set_serial_additions(1113, rr('A', 'abc.ruby-lang.org', '1.1.1.3'))
      h.set_serial_additions(1114, rr('A', 'abc.ruby-lang.org', '1.1.1.4'))
      h.set_serial_deletions(1114, rr('A', 'abc.ruby-lang.org', '1.1.1.3'))
      h
    end

    it "defaults to :never when a ixfr_response_uses_axfr_style value is not provided" do
      expect(SerialHistory.new('ruby-lang.org', 1001).ixfr_response_uses_axfr_style).to eq(:never)
    end

    it "returns :single_soa when the query's serial == the highest_serial" do
      history.ixfr_response_uses_axfr_style = :never
      expect(history.ixfr_response_style(1114)).to eq(:single_soa)

      history.ixfr_response_uses_axfr_style = :auto
      expect(history.ixfr_response_style(1114)).to eq(:single_soa)

      history.ixfr_response_uses_axfr_style = :always
      expect(history.ixfr_response_style(1114)).to eq(:single_soa)
    end

    it "returns :single_soa when the query's serial > the highest_serial" do
      history.ixfr_response_uses_axfr_style = :never
      expect(history.ixfr_response_style(1115)).to eq(:single_soa)

      history.ixfr_response_uses_axfr_style = :auto
      expect(history.ixfr_response_style(1115)).to eq(:single_soa)

      history.ixfr_response_uses_axfr_style = :always
      expect(history.ixfr_response_style(1115)).to eq(:single_soa)
    end

    it "returns :ixfr for :never when the serial is tracked and < the highest serial" do
      expect(history.ixfr_response_style(1111)).to eq(:ixfr)
      expect(history.ixfr_response_style(1113)).to eq(:ixfr)
    end

    it "returns :xfer_failed for :never when the serial number is NOT tracked and < the highest serial" do
      expect(history.ixfr_response_style(1110)).to eq(:xfer_failed)
    end

    it "returns :ixfr for :auto when the serial is tracked and < the highest serial" do
      history.ixfr_response_uses_axfr_style = :auto
      expect(history.ixfr_response_style(1111)).to eq(:ixfr)
      expect(history.ixfr_response_style(1113)).to eq(:ixfr)
    end

    it "returns :axfr_style_ixfr for :auto when the serial is NOT tracked and < the highest serial" do
      history.ixfr_response_uses_axfr_style = :auto
      expect(history.ixfr_response_style(1110)).to eq(:axfr_style_ixfr)
    end

    it "returns :axfr_style_ixfr for :always when the serial is NOT tracked and < the highest serial" do
      history.ixfr_response_uses_axfr_style = :always
      expect(history.ixfr_response_style(1110)).to eq(:axfr_style_ixfr)
    end

    it "returns :axfr_style_ixfr for :always when the serial is tracked and < the highest serial" do
      history.ixfr_response_uses_axfr_style = :always
      expect(history.ixfr_response_style(1112)).to eq(:axfr_style_ixfr)
    end

  end


  context "SerialHistory#is_tracked_serial" do

    let(:history) do
      h = SerialHistory.new('ruby-lang.org', 1111)
      h.set_serial_additions(1112, rr('A', 'abc.ruby-lang.org', '1.1.1.2'))
      h.set_serial_additions(1113, rr('A', 'abc.ruby-lang.org', '1.1.1.3'))
      h
    end

    it 'considers the low serial tracked' do
      expect(history.is_tracked_serial(1111)).to be true
    end

    it 'considers the high serial tracked' do
      expect(history.is_tracked_serial(1113)).to be true
    end

    it 'considers a too-low serial not tracked' do
      expect(history.is_tracked_serial(1110)).to be false
    end

    it 'considers a too-high serial not tracked' do
      expect(history.is_tracked_serial(1114)).to be false
    end
  end


  context 'handles 0xFFFF_FFFF rollover' do
    specify 'handles rollover from initial number' do
      h = SerialHistory.new('ruby-lang.org', 0xFFFF_FFFF)
      expect(->() { h.set_serial_additions(0, rr('A', 'abc.ruby-lang.org', '1.1.1.2')) }).not_to raise_error
      expect(h.low_serial.value).to eq(0xFFFF_FFFF)
      expect(h.high_serial.value).to eq(0)
    end

    specify 'handles rollover from initial number' do
      h = SerialHistory.new('ruby-lang.org', 0xFFFF_FFFE)
      h.set_serial_additions(0xFFFF_FFFF, rr('A', 'abc.ruby-lang.org', '1.1.1.2'))
      h.set_serial_additions(0, rr('A', 'abc.ruby-lang.org', '1.1.1.3'))
      expect(h.low_serial.value).to eq(0xFFFF_FFFE)
      expect(h.high_serial.value).to eq(0)
    end
  end

  context "SerialHistory#next_serial_value" do

    specify 'offers the correct next serial value for 0' do
      h = SerialHistory.new('ruby-lang.org', 0)
      expect(h.next_serial_value).to eq(1)
    end

    specify 'offers the correct next serial value for 0xFFFF_FFFF' do
      h = SerialHistory.new('ruby-lang.org', 0xFFFF_FFFF)
      expect(h.next_serial_value).to eq(0)
    end
  end
end
end

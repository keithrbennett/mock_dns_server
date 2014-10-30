require 'mock_dns_server/message_transformer'

module MockDnsServer

class HistoryInspections

  MT = MessageTransformer

  def type(type)
    ->(record) { record[:type] == type }
  end

  def qtype(qtype)
    ->(record) do
      qtype_in_message = MT.new(record[:message]).qtype.to_s
      qtype_in_message == qtype
    end
  end

  def qname(qname)
    ->(record) do
      qname_in_message = MT.new(record[:message]).qname.to_s
      qname_in_message == qname
    end
  end

  def soa
    qtype('SOA')
  end

  def protocol(protocol)
    ->(record) { record[:protocol] == protocol }
  end

  def all(*inspections)
    ->(record) do
      inspections.all? { |inspection| inspection.(record) }
    end
  end

  def any(*inspections)
    ->(record) do
      inspections.any? { |inspection| inspection.(record) }
    end
  end

  def none(*inspections)
    ->(record) do
      inspections.none? { |inspection| inspection.(record) }
    end
  end

  def apply(records, inspection)
    records.select { |record| inspection.(record) }
  end
end

end

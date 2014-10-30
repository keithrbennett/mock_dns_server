module MockDnsServer

# Handles the history of events for this server.
class History

  def initialize(context)
    @context = context
    @records = ThreadSafe::Array.new
  end


  def size
    @records.size
  end


  def add(entry_hash)
    entry_hash[:time] ||= Time.now
    @records << entry_hash
    entry_hash
  end


  def add_incoming(message, sender, protocol, description = nil)
    add( {
      type: :incoming,
      message: message,
      sender: sender,
      protocol: protocol,
      description: description
    })
  end


  def add_action_not_found(message)
    add( {
      type: :action_not_found,
      message: message
    })
  end


  def add_conditional_action_removal(conditional_action)
    add( {
      type: :conditional_action_removal,
      conditional_action: conditional_action
    })
  end


  def add_notify_response(response, zts_host, zts_port, protocol)
    add( {
        type: :notify_response,
        message: response,
        host: zts_host,
        port: zts_port,
        protocol: protocol,
        description: "notify response from #{zts_host}:#{zts_port}"
    })
  end


  def occurred?(inspection)
    HistoryInspections.new.apply(@records, inspection).size > 0
  end


  # @return a clone of the array
  def to_a
    @records.clone
  end


  def copy
    @records.map { |record| record.clone }
  end


  def to_s
    "#{super}: #{@records}"
  end

end
end

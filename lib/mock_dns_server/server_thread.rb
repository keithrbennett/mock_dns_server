module MockDnsServer

class ServerThread < Thread

  attr_accessor :server

  # Thread::abort_on_exception = true

  def self.all
    Thread.list.select { |thread| thread.is_a?(ServerThread) }
  end
end
end

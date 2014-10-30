require_relative '../spec_helper'
require 'socket'

module MockDnsServer

# These tests were for research purposes only and are not related to the correct operation
# of this gem. It turns out that the results of these tests differed on different OS's.

=begin

describe "UDP sockets" do

  it "should be able to immediately reuse an address (port) if the previous socket was closed" do
    port = 8870
    socket = UDPSocket.new
    socket.bind(nil, port)
    socket.close

    expect(-> do
      socket = UDPSocket.new
      socket.bind(nil, port)
      socket.close
    end).to_not raise_error

  end


  it "should NOT be able to immediately reuse an address (port) if the previous socket was NOT closed" do
    port = 8860
    socket = UDPSocket.new
    socket.bind(nil, port)

    expect(-> do
      socket = UDPSocket.new
      socket.bind(nil, port)
      socket.close
    end).to raise_error
  end


  it "should NOT be able to immediately reuse an address (port) if the previous socket was NOT closed even if REUSEADDR was enabled" do
    port = 8884
    socket = UDPSocket.new
    socket.setsockopt(Socket::SOL_SOCKET,Socket::SO_REUSEADDR, true)
    socket.bind(nil, port)

    expect(-> do
      socket2 = UDPSocket.new
      socket2.setsockopt(Socket::SOL_SOCKET,Socket::SO_REUSEADDR, true)
      socket2.bind(nil, port)
      socket2.close
    end).to raise_error

  end

end

=end
end

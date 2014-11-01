[![Build Status](https://travis-ci.org/keithrbennett/mock_dns_server.svg)](https://travis-ci.org/keithrbennett/mock_dns_server)

# MockDnsServer

A mock DNS server that can be instructed to perform actions based on
user-provided conditions, and queried for its history of inputs and outputs.
This server listens and responds on both UDP and TCP ports.

An admin interface is provided, currently in the form of Ruby methods that
can be called.  In the future we will probably add an HTTP interface
to these methods. The admin methods:

* instructing the server how to respond given the characteristics of the request
* query the server for its history of inputs and outputs
* request shutdown


## Implementation


### Threads

```server.start``` launches its own thread in which it runs. This thread is terminated when ```server.close``` is called.

Admin requests (configuration, analysis, etc.) will occur on the caller's thread.


### Starting a Server

The simplest way to run a server is to call the convenience method ```Server#with_new_server```:

```ruby
  Server.with_new_server(options) do |server|
    # configure server with conditional actions
    server.start
  end
```

Options currently consist of:

Option Name|Default Value|Description
-----------|-------------|-----------|
port       | 53          | port on which to listen (UDP and TCP)
timeout    | 0.25 sec    | timeout for IO.select call
verbose    | false       | Whether or not to output diagnostic messages

The code above will result in the creation of a new thread in which the server will listen
and respond indefinitely.  Terminating the server is accomplished by calling server.close
in the caller's thread.


### Locking

A single mutex will be used to protect access to the rules and history objects.
All mutex handling will be done by code in this gem, so the caller does not
need to know or care that it is being done.


### Message Read Loop

The server will have the following flow of execution:

```
loop do
  read a packet
  attempt to parse it into a Dnsruby::Message object; if not, the message will be a string
  mutex.synchronize do
    action = look up rule
    action.call # (perform appropriate action -- send or don't send response, etc.)
    add input and output to history
  end
end
```

The above loop is wrapped in an IO.select timeout loop, although currently nothing
is done at timeout time.  (Closing the server is accomplished by calling server.close
on the caller's thread.)

For TCP, since the application layer requires that the transmission begin with a 2-byte
message length field (which is packed/unpacked with 'n'), this field is read first,
and the server continues reading until the entire transmission is read.

### Conditional Actions

The server can be set up with conditional actions that will control how it responds to
incoming requests.  Basically, a ConditionalAction consists of a proc (usually a lambda)
that will be called to determine whether or not the action should be executed,
and another proc (also usually a lambda) defining the action that should be performed.

Only one conditional action will be performed per incoming request.
The conditions in the conditional actions are evaluated in the order with which
they were added to the server.  When a condition returns true, the corresponding
action will be performed, and the message loop iteration will end.

For more information about how conditional actions are created, see the ConditionalAction,
PredicateFactory, ActionFactory, and ConditionalActionFactory classes.  For how
the conditional actions are searched and performed, see the ConditionalActions class.


### History

To get a history of the server's events, call ```server.history_copy```.


## Installation

Add this line to your application's Gemfile:

    gem 'mock_dns_server'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install mock_dns_server

## Usage

TODO: Write usage instructions here

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

require 'dnsruby'

# When adding an RR to a Dnsruby::Message, add_answer checks to see if it already occurs,
# and, if so, does not add it again. We need to disable this behavior so that we can
# add a SOA record twice for an AXFR response.  So we implement add_answer!,
# similar to add_answer except that it does not do the inclusion check.

module Dnsruby
  class Message

    def add_answer!(rr) #:nodoc: all
      #if (!@answer.include?rr)
        @answer << rr
        update_counts
      #end
    end
  end
end


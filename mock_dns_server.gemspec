# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'mock_dns_server/version'

Gem::Specification.new do |spec|
  spec.name          = 'mock_dns_server'
  spec.version       = MockDnsServer::VERSION
  spec.authors       = ['Keith Bennett']
  spec.email         = ['keithrbennett@gmail.com']
  spec.description   = %q{Mock DNS Server}
  spec.summary       = %q{Mock DNS Server}
  spec.homepage      = 'https://github.com/keithrbennett/mock_dns_server'
  spec.license       = 'BSD-3-Clause'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'dnsruby', '~> 1.54'
  spec.add_dependency 'hexdump', '> 0.2'
  spec.add_dependency 'thread_safe', '~> 0.3'

  spec.add_dependency 'awesome_print', '~> 1.2'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '~> 3.0'

end

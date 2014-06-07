# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'mock_em/version'

Gem::Specification.new do |gem|
  gem.name             = "mock_em"
  gem.version          = MockEM::VERSION

  gem.authors          = ['Jim Slattery, Dominic Metzger']
  gem.date             = "2014-05-30"

  gem.summary          = %q{Mock for EM for testing.}
  gem.description      = %q{Mock EM}
  gem.homepage         = "https://github.com/rightscale/mock_em"
  gem.email            = 'support@rightscale.com'
  gem.licenses         = ["MIT"]

  gem.files            = `git ls-files`.split($/)
  gem.executables      = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files       = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths    = [ "lib" ]
  gem.extra_rdoc_files = [ "LICENSE", "README.rdoc" ]
  gem.rubygems_version = "1.8.26"

  gem.add_dependency("timecop", "0.3.4")
  # ---------------------------------------------------------------------
  # Test suite
  # ---------------------------------------------------------------------
  gem.add_development_dependency("rspec",        '3.0.0')
  gem.add_development_dependency('ruby-debug',   '0.10.4')
  gem.add_development_dependency('eventmachine', '1.0.3')
end

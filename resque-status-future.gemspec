# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "resque-status-future"
  spec.version       = "0.4.0"
  spec.authors       = ["Rich Daley"]
  spec.email         = ["rich@fishpercolator.co.uk"]

  spec.summary       = %q{Adds support for futures to resque-status}
  spec.homepage      = "https://github.com/fishpercolator/resque-status-future"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'resque-status', '~> 0.5'

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "pry"
  spec.add_development_dependency 'simplecov'
end

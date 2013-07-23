# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'maruto/version'

Gem::Specification.new do |spec|
  spec.name          = "maruto"
  spec.version       = Maruto::VERSION
  spec.authors       = ["Jean-Luc Geering"]
  spec.email         = ["jlgeering.13@gmail.com"]
  spec.description   = %q{Magento Ruby Tools}
  spec.summary       = %q{config parser and analyser, ...}
  spec.homepage      = "https://github.com/jlgeering/maruto"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "nokogiri", "~> 1.6"
  spec.add_dependency "thor", "~> 0.17"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest", "~> 5"
  # spec.add_development_dependency "minitest-reporters"
end

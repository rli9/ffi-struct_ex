# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ffi/struct_ex/version'

Gem::Specification.new do |spec|
  spec.name          = "ffi-struct_ex"
  spec.version       = Ffi::StructEx::VERSION
  spec.authors       = ["Ruijia Li"]
  spec.email         = ["ruijia.li@gmail.com"]
  spec.description   = %q{A module to add extra functionalities to FFI::Struct}
  spec.summary       = %q{A module to add extra functionalities to FFI::Struct}
  spec.homepage      = "https://github.com/rli9/ffi-struct_ex"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "ffi", "~> 1.0"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end

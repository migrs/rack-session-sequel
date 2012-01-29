# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "rack-session-sequel/version"

Gem::Specification.new do |s|
  s.name        = "rack-session-sequel"
  s.version     = Rack::Session::Sequel::VERSION
  s.authors     = ["Masato Igarashi"]
  s.email       = ["m@igrs.jp"]
  s.homepage    = "http://github.com/migrs/rack-session-sequel"
  s.summary     = %q{Rack session store for Sequel}
  s.description = %q{Rack session store for Sequel}

  #s.rubyforge_project = "rack-session-sequel"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency "bacon"
  s.add_runtime_dependency "rack"
  s.add_runtime_dependency "sequel"
end

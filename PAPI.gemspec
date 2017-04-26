Gem::Specification.new do |s|
  s.name = 'PAPI'
  s.version = "1.0.0"
  s.author = "Brice Videau"
  s.email = "brice.videau@imag.fr"
  s.homepage = "https://github.com/Nanosim-LIG/papi-ruby"
  s.summary = "Ruby PAPI bindings"
  s.description = "Ruby PAPI bindings."
  s.files = %w( PAPI.gemspec LICENSE lib/PAPI.rb lib/PAPI/ lib/PAPI/Version.rb lib/PAPI/Error.rb lib/PAPI/Thread.rb lib/PAPI/Event.rb lib/PAPI/Component.rb lib/PAPI/EventSet.rb )
  s.has_rdoc = true
  s.license = 'BSD-2-Clause'
  s.required_ruby_version = '>= 1.9.3'
  s.add_dependency 'ffi', '~> 1.9', '>=1.9.3'
end

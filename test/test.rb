[ '../lib', 'lib' ].each { |d| $:.unshift(d) if File::directory?(d) }
require 'PAPI'

puts "Found PAPI #{PAPI::VERSION}"
puts "-----------"
set = PAPI::EventSet::new
puts set.possible
puts "-----------"
set.add(PAPI::L1_DCM)
set.add_named("PAPI_L2_DCM")
puts set.possible
set.start
puts vals = set.stop
set.start
set.accum(vals)
puts vals
puts set.stop
puts set.read
puts set.events
puts set.read_ts
puts "-----------"
set = PAPI::EventSet::new
puts set.possible(false)
if PAPI::COMPONENTS.length > 1 then
  puts "-----------"
  set = PAPI::EventSet::new
  set.assign_component(PAPI::COMPONENTS[1])
  puts set.possible(false)
end


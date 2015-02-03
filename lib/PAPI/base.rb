require 'ffi'

module PAPI

  extend FFI::Library

  ffi_lib "libpapi.so"
  attach_function :PAPI_library_init, [ :int ], :int
  attach_function :PAPI_shutdown, [ :void ], :void

  class Version

    def initialize( *vals )
      if( vals.length > 1 )
        @number = 0
        4.times {
          v = vals.shift
          v = 0 unless v
          @number <<= 8
          @number += v & 0xff
        }
      else
        @number = vals[0]
      end
    end

    def major
      return ( @number >> 24 ) & 0xff
    end

    def minor
      return ( @number >> 16 ) & 0xff
    end

    def revision
      return ( @number >> 8 ) & 0xff
    end

    def increment
      return @number & 0xff
    end

    def to_int
      return @number
    end

  end

  def self.init
    major = 5
    4.downto(0) { |minor|
      res = PAPI_library_init(Version::new(major, minor))
      if res != -1 then
        return Version::new(res)
      end
    }
  end

  v = self.init()
  puts "Found PAPI #{v.major}.#{v.minor}.#{v.revision}.#{v.increment}"

end

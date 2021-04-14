require 'ffi'

module PAPI

  extend FFI::Library

  ffi_lib "papi"
  attach_function :PAPI_library_init, [ :int ], :int
  attach_function :PAPI_shutdown, [ ], :void

  class Version
    include Comparable

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

    def to_s
      return "#{major}.#{minor}.#{revision}.#{increment}"
    end

    def <=>(v)
      return self.to_int <=> v.to_int
    end
  end

  def self.init
    6.downto(3) { |major|
      9.downto(0) { |minor|
        9.downto(0) { |revision|
          9.downto(0) { |increment|
            v = Version::new(major, minor, revision, increment)
            res = PAPI_library_init(v)
            if res == v.to_int then
              return Version::new(res)
            end
          }
        }
      }
    }
    return nil
  end

  def self.shutdown
    PAPI_shutdown()
    return self
  end

  VERSION = self.init()

end

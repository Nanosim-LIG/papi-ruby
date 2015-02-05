require 'ffi'

module PAPI

  extend FFI::Library

  ffi_lib "libpapi.so"
  attach_function :PAPI_library_init, [ :int ], :int
  attach_function :PAPI_shutdown, [ :void ], :void

  MIN_STR_LEN = 64
  MAX_STR_LEN = 128
  MAX_STR_LEN2 = 256
  HUGE_STR_LEN = 1024
  MAX_INFO_TERMS = 12

  OK = 0

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
    5.downto(3) { |major|
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

  VERSION = self.init()
  puts "Found PAPI #{VERSION}"

  class Event
    PRESET_MASK = 0x80000000
    NATIVE_MASK = 0x40000000
    PRESET_AND_MASK = 0x7FFFFFFF
    NATIVE_AND_MASK = 0xBFFFFFFF

    MAX_PRESET_EVENTS = 128

    attr_reader :info

    def initialize(info)
      @info = info
    end

    def to_i
      @info[:event_code]
    end

    def to_s
      @info[:symbol].to_ptr.read_string
    end

    class Info < FFI::Struct
      if VERSION >= Version::new(5,0,0,0) then
        layout :event_code,      :uint,
               :symbol,         [:char, HUGE_STR_LEN],
               :short_descr,    [:char, MIN_STR_LEN],
               :long_descr,     [:char, HUGE_STR_LEN],
               :component_index, :int,
               :units,          [:char, MIN_STR_LEN],
               :location,        :int,
               :data_type,       :int,
               :value_type,      :int,
               :timescope,       :int,
               :update_type,     :int,
               :update_freq,     :int,
               :count,           :uint,
               :event_type,      :uint,
               :derived,        [:char, MIN_STR_LEN],
               :postfix,        [:char, MAX_STR_LEN2],
               :code,           [:int,  MAX_INFO_TERMS],
               :name,           [:char, MAX_INFO_TERMS*MAX_STR_LEN2],
               :note,           [:char, HUGE_STR_LEN]
      else
        layout :event_code,      :uint,
               :event_type,      :uint,
               :count,           :uint,
               :symbol,         [:char, HUGE_STR_LEN],
               :short_descr,    [:char, MIN_STR_LEN],
               :long_descr,     [:char, HUGE_STR_LEN],
               :derived,        [:char, MIN_STR_LEN],
               :postfix,        [:char, MIN_STR_LEN],
               :code,           [:int,  MAX_INFO_TERMS],
               :name,           [:char, MAX_INFO_TERMS*MAX_STR_LEN2],
               :note,           [:char, HUGE_STR_LEN]
      end
    end
  end

  typedef :pointer, :papi_event_info_t

  EventModifier = enum( :enum_events,
                        :enum_first,
                        :preset_enum_avail,
                        :preset_enum_msc,
                        :preset_enum_ins,
                        :preset_enum_idl,
                        :preset_enum_br,
                        :preset_enum_cnd,
                        :preset_enum_mem,
                        :preset_enum_cach,
                        :preset_enum_l1,
                        :preset_enum_l2,
                        :preset_enum_l3,
                        :preset_enum_tlb,
                        :preset_enum_fp,
                        :ntv_enum_umasks,
                        :ntv_enum_umasks_combos,
                        :ntv_enum_iarr,
                        :ntv_enum_darr,
                        :ntv_enum_opcm,
                        :ntv_enum_iear,
                        :ntv_enum_dear,
                        :ntv_enum_groups )

  attach_function :PAPI_enum_event, [:pointer, EventModifier], :int
  attach_function :PAPI_get_event_info, [:int, :papi_event_info_t], :int

  PRESET_EVENTS = []

  def self.get_events_info
    e_p = FFI::MemoryPointer::new(:uint)
    e_p.write_uint(0 | Event::PRESET_MASK)
    PAPI_enum_event(e_p, :enum_first)
    info = Event::Info::new
    e = PAPI_get_event_info( e_p.read_int, info )
    PRESET_EVENTS.push(Event::new(info))
    while PAPI_enum_event(e_p, :preset_enum_avail) == OK do
      info = Event::Info::new
      e = PAPI_get_event_info( e_p.read_int, info )
      PRESET_EVENTS.push(Event::new(info))
    end
    PRESET_EVENTS.each { |ev|
      puts "#{ev}\t: 0x#{ev.to_i.to_s(16)}"
    }
  end

  self.get_events_info
end

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

  PAPI_NULL = -1

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

  class Error < StandardError
    attr_reader :code

    def initialize(code)
      @code = code
      super("#{code}")
    end

    #:stopdoc:
    CLASSES = {}
    #:startdoc:

    private_constant :CLASSES

    def self.error_class(errcode)
      return CLASSES[errcode]
    end

    def self.name(code)
      if CLASSES[code] then
        return CLASSES[code].name
      else
        return "#{code}"
      end
    end

    def name
      return "#{@code}"
    end

    def self.register_error(code, symbol)
      s = <<EOF
      class #{symbol} < Error

        def initialize
          super(#{code})
        end

        def self.name
          return "#{code}"
        end

        def name
          return "#{code}"
        end

        def self.code
          return #{code}
        end

      end
      CLASSES[#{code}] = #{symbol}
EOF
      eval s
    end
    errors = []
    errors.push([-1, "EINVAL"],    
                [-2, "ENOMEM"],
                [-3, "ESYS"])
    if VERSION >= Version::new(5,0,0,0) then
      errors.push [-4, "ECMP"]
    else
      errors.push [-4, "ESBSTR"]
    end
    errors.push([-5, "ECLOST"],
                [-6, "EBUG"],
                [-7, "ENOEVNT"],
                [-8, "ECNFLCT"],
                [-9, "ENOTRUN"],
                [-10, "EISRUN"],
                [-11, "ENOEVST"],
                [-12, "ENOTPRESET"],
                [-13, "ENOCNTR"],
                [-14, "EMISC"],
                [-15, "EPERM"],
                [-16, "ENOINIT"])
    if VERSION >= Version::new(4,2,0,0) then
      errors.push([-17, "ENOCMP"],
                  [-18, "ENOSUPP"],
                  [-19, "ENOIMPL"],
                  [-20, "EBUF"],
                  [-21, "EINVAL_DOM"],
                  [-22, "EATTR"],
                  [-23, "ECOUNT"],
                  [-24, "ECOMBO"])
    elsif VERSION >= Version::new(4,1,0,0) then
      errors.push([-17, "ENOCMP"],
                  [-18, "ENOSUPP"],
                  [-19, "ENOIMPL"],
                  [-20, "EBUF"],
                  [-21, "EINVAL_DOM"])
    elsif VERSION >= Version::new(4,0,0,0) then
      errors.push([-17, "EBUF"],
                  [-18, "EINVAL_DOM"],
                  [-19, "ENOCMP"])
    else
      errors.push([-17, "EBUF"],
                  [-18, "EINVAL_DOM"])
    end
    errors.each  { |code, symbol| register_error(code, symbol) }

  end

  def self.error_check(errcode)
      return nil if errcode >= OK
      klass = Error::error_class(errcode)
      if klass then
        raise klass::new
      else
        raise Error::new("#{errcode}")
      end
  end

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
        layout :event_code,      :int,
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
  PRESET_EVENTS_HASH = {}

  def self.get_events_info
    e_p = FFI::MemoryPointer::new(:uint)
    e_p.write_uint(0 | Event::PRESET_MASK)
    PAPI_enum_event(e_p, :enum_first)
    info = Event::Info::new
    e = PAPI_get_event_info( e_p.read_int, info )
    ev = Event::new(info)
    PRESET_EVENTS.push(ev)
    PRESET_EVENTS_HASH[ev.to_i] = ev
    while PAPI_enum_event(e_p, :preset_enum_avail) == OK do
      info = Event::Info::new
      e = PAPI_get_event_info( e_p.read_int, info )
      ev = Event::new(info)
      PRESET_EVENTS.push(ev)
      PRESET_EVENTS_HASH[ev.to_i] = ev
    end
    PRESET_EVENTS.each { |ev|
      puts "#{ev}"
    }
  end

  get_events_info

  PRESET_EVENTS.each_index { |i|
    s  = <<EOF
  #{PRESET_EVENTS[i].to_s.gsub("PAPI_","")} = PRESET_EVENTS[#{i}]
EOF
    eval s
  }

  typedef :int, :event_set
  attach_function :PAPI_create_eventset, [:pointer], :int
  attach_function :PAPI_add_event, [:event_set, :int], :int
  attach_function :PAPI_remove_event, [:event_set, :int], :int
  attach_function :PAPI_num_events, [:event_set], :int
  attach_function :PAPI_list_events, [:event_set, :pointer, :pointer], :int
  attach_function :PAPI_start, [:event_set], :int
  attach_function :PAPI_stop, [:event_set, :pointer], :int
  attach_function :PAPI_accum, [:event_set, :pointer], :int
  attach_function :PAPI_read, [:event_set, :pointer], :int
  attach_function :PAPI_read_ts, [:event_set, :pointer, :pointer], :int

  class EventSet


    def initialize
      number = FFI::MemoryPointer::new(:int)
      number.write_int(PAPI_NULL)
      error = PAPI::PAPI_create_eventset( number )
      @number = number.read_int
      PAPI::error_check(error)
      @size = 0
    end

    def add( events )
      evts = [events].flatten
      evts.each { |ev|
        error = PAPI::PAPI_add_event(@number, ev.to_i)
        PAPI::error_check(error)
      }
      error = PAPI::PAPI_num_events(@number)
      PAPI::error_check(error)
      @size = error
      return self
    end

    def remove( events )
      evts = [events].flatten
      evts.each { |ev|
        error = PAPI::PAPI_remove_event(@number, ev.to_i)
        PAPI::error_check(error)
      }
      error = PAPI::PAPI_num_events(@number)
      PAPI::error_check(error)
      @size = error
      return self
    end

    def possible
      list = []
      PRESET_EVENTS.each { |event|
        error = PAPI::PAPI_add_event(@number, event.to_i)
        if( error >= OK ) then
          error = PAPI::PAPI_remove_event(@number, event.to_i)
          PAPI::error_check(error)
          list.push event
        end
      }
      return list
    end

    def size
      return @size
    end

    alias length size
    alias num_events size

    def events
      events_p = FFI::MemoryPointer::new(:int, @size)
      size_p = FFI::MemoryPointer::new(:int)
      size_p.write_int(@size)
      error = PAPI::PAPI_list_events(@number, events_p, size_p)
      PAPI::error_check(error)
      evts = events_p.read_array_of_int(size_p.read_int)
      return evts.collect { |code| PRESET_EVENTS_HASH[code] }
    end

    alias list_events events

    def start
      error = PAPI::PAPI_start(@number)
      PAPI::error_check(error)
      return self
    end

    def stop
      values_p = FFI::MemoryPointer::new(:long_long, @size)
      error = PAPI::PAPI_stop(@number, values_p)
      PAPI::error_check(error)
      return values_p.read_array_of_long_long(@size)
    end

    def accum(values)
      values_p = FFI::MemoryPointer::new(:long_long, @size)
      values_p.write_array_of_long_long(values)
      error = PAPI::PAPI_accum(@number, values_p)
      PAPI::error_check(error)
      new_values = values_p.read_array_of_long_long(@size)
      values.replace(new_values)
      return self
    end

    def read
      values_p = FFI::MemoryPointer::new(:long_long, @size)
      error = PAPI::PAPI_read(@number, values_p)
      PAPI::error_check(error)
      return values_p.read_array_of_long_long(@size)
    end

    def read_ts
      values_p = FFI::MemoryPointer::new(:long_long, @size)
      ts_p = FFI::MemoryPointer::new(:long_long)
      error = PAPI::PAPI_read_ts(@number, values_p, ts_p)
      PAPI::error_check(error)
      return [values_p.read_array_of_long_long(@size), ts_p.read_long_long]
    end

  end

  puts "-----------"

  set = EventSet::new
  set.add(L1_DCM)
  set.add(L2_DCM)
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
  
end

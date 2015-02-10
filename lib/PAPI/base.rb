require 'ffi'

module PAPI

  extend FFI::Library

  ffi_lib "libpapi.so"
  attach_function :PAPI_library_init, [ :int ], :int
  attach_function :PAPI_shutdown, [ ], :void

  MIN_STR_LEN = 64
  MAX_STR_LEN = 128
  MAX_STR_LEN2 = 256
  HUGE_STR_LEN = 1024
  MAX_INFO_TERMS = 12
  PMU_MAX = 40

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
          return "#{symbol}"
        end

        def name
          return "#{symbol}"
        end

        def self.code
          return #{code}
        end

      end
      CLASSES[#{code}] = #{symbol}
EOF
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
    errors.each  { |code, symbol| eval register_error(code, symbol) }

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
    class Mask < Event
      def initialize(info)
        super(info,nil)
      end       
    end

    PRESET_MASK = 0x80000000
    NATIVE_MASK = 0x40000000
    PRESET_AND_MASK = 0x7FFFFFFF
    NATIVE_AND_MASK = 0xBFFFFFFF

    MAX_PRESET_EVENTS = 128

    attr_reader :info
    attr_reader :masks

    def initialize(info, masks = nil)
      @info = info
      @masks = masks
    end

    def to_i
      @info[:event_code]
    end

    def to_s(description = false, masks = false)
      s1 = @info[:symbol].to_ptr.read_string
      s = "#{s1}"
      s += "\n  #{@info[:long_descr]}" if description
      if masks and @masks then
        s += "\n    "
        s += @masks.collect{ |m| m.to_s.gsub(s1.gsub(/.*::/,""),"")+"\n      " + m.info[:long_descr].to_ptr.read_string.gsub(/.*masks:/,"") }.join("\n    ")
      end
      return s
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
    # PRESET_EVENTS.each { |ev| puts "#{ev.to_s(true)}" }
  end

  get_events_info

  PRESET_EVENTS.each_index { |i|
    s  = <<EOF
  #{PRESET_EVENTS[i].to_s.gsub("PAPI_","")} = PRESET_EVENTS[#{i}]
EOF
    eval s
  }

  if VERSION >= Version::new(4,0,0,0) then
    attach_function :PAPI_num_components, [], :int
    attach_function :PAPI_get_component_info, [:int], :pointer
    attach_function :PAPI_enum_cmp_event, [:pointer, EventModifier, :int], :int 	
  else
    attach_function :PAPI_get_substrate_info, [], :pointer
  end

  COMPONENTS = []
  COMPONENTS_HASH = {}

  class Component
    class Info < FFI::Struct
      lay = []
      lay.push(:name,                   [:char, MAX_STR_LEN])
      lay.push(:short_name,             [:char, MIN_STR_LEN],
               :description,            [:char, MAX_STR_LEN]) if  VERSION >= Version::new(5,0,0,0)
      lay.push(:version,                [:char, MIN_STR_LEN],
               :support_version,        [:char, MIN_STR_LEN],
               :kernel_version,         [:char, MIN_STR_LEN])
      lay.push(:disabled_reason,        [:char, MAX_STR_LEN],
               :disabled,                :int) if VERSION >= Version::new(5,0,0,0)
      lay.push(:CmpIdx,                  :int) if VERSION >= Version::new(4,0,0,0)
      lay.push(:num_cntrs,               :int,
               :num_mpx_cntrs,           :int,
               :num_preset_events,       :int,
               :num_native_events,       :int,
               :default_domain,          :int,
               :available_domains,       :int,
               :default_granularity,     :int,
               :available_granularities, :int)
      lay.push(:itimer_sig,              :int,
               :itimer_num,              :int,
               :itimer_ns,               :int,
               :itimer_res_ns,           :int) if VERSION < Version::new(5,0,0,0)
      lay.push(:hardware_intr_sig,       :int)
      lay.push(:clock_ticks,             :int,
               :opcode_match_width,      :int) if VERSION < Version::new(5,0,0,0)
      lay.push(:component_type,          :int) if VERSION >= Version::new(5,0,0,0)
      lay.push(:pmu_names,              [:pointer, PMU_MAX]) if VERSION >= Version::new(5,4,1,0)
      lay.push(:reserved,               [:int, 8]) if VERSION >= Version::new(5,0,0,0)
      lay.push(:os_version,              :int,
               :reserved,               [:int, 1]) if VERSION < Version::new(5,0,0,0) and VERSION >= Version::new(4,1,1,0)
      lay.push(:reserved,               [:int, 2]) if VERSION < Version::new(4,1,1,0)
      lay.push(:bifield,                 :uint)

      layout( *lay )
    end

    attr_reader :info
    attr_accessor :native
    attr_accessor :preset

    def initialize(info, idx = 0)
      @info = info
      @idx = idx
    end

    def to_i
      return @idx
    end

    def to_s
      @info[:name].to_ptr.read_string
    end

  end

  def self.get_mask_info( code, component )
    m_p = FFI::MemoryPointer::new(:uint)
    m_p.write_uint( code.read_uint )
    if VERSION < Version::new(4,0,0,0) then
      e = PAPI_enum_event( m_p, :ntv_enum_umasks )
    else
      e = PAPI_enum_cmp_event( m_p, :ntv_enum_umasks, component.to_i )
    end
    return nil if e != OK
    info = Event::Info::new
    e = PAPI_get_event_info( m_p.read_int, info )
    if e == OK then
      ev = Event::new(info)
      masks = []
      masks.push(ev)
    end
    while ( VERSION < Version::new(4,0,0,0) ? PAPI_enum_event(e_p, :ntv_enum_umasks) : PAPI_enum_cmp_event( m_p, :ntv_enum_umasks, component.to_i ) ) == OK do
      info = Event::Info::new
      e = PAPI_get_event_info( m_p.read_int, info )
      next if e != OK
      ev = Event::new(info)
      masks = [] if not masks
      masks.push(ev)
    end
    return masks
  end

  def self.get_native_events( component )
    e_p = FFI::MemoryPointer::new(:uint)
    e_p.write_uint(0 | Event::NATIVE_MASK)
    if VERSION < Version::new(4,0,0,0) then
      e = PAPI_enum_event(e_p, :enum_first)
    else
      e = PAPI_enum_cmp_event(e_p, :enum_first, component.to_i)
    end
    return if e != OK
    info = Event::Info::new
    e = PAPI_get_event_info( e_p.read_int, info )
    if e == OK then
      ev = Event::new(info, get_mask_info( e_p, component ))
      component.native = []
      component.native.push(ev)
    end
    while ( VERSION < Version::new(4,0,0,0) ? PAPI_enum_event(e_p, :enum_events) : PAPI_enum_cmp_event(e_p, :enum_events, component.to_i) ) == OK do
      info = Event::Info::new
      e = PAPI_get_event_info( e_p.read_int, info )
      next if e != OK
      ev = Event::new(info, get_mask_info( e_p, component ) )
      component.native = [] if not component.native
      component.native.push(ev)
    end

    puts "-----------"
    puts "#{component}: #{component.to_i}"
    puts component.native.length
    #component.native.each { |evt| puts evt.to_s(true, true) }
  end

  def self.get_components_info
    puts "-----------"
    if VERSION < Version::new(4,0,0,0) then
      info_p = PAPI_get_substrate_info()
      COMPONENTS.push( Component::new(Component::Info::new(info_p)))
      COMPONENTS_HASH[0] = COMPONENTS[0]
    else
      (0...PAPI_num_components()).each { |cid|
        info_p = PAPI_get_component_info(cid)
        info = Component::Info::new(info_p)
        if VERSION >= Version::new(5,0,0,0) and info[:disabled] != 0 then
          puts "#{info[:name].to_ptr.read_string}: #{info[:disabled_reason].to_ptr.read_string}"
        else
          COMPONENTS.push( Component::new(info, cid) )
          COMPONENTS_HASH[cid] = COMPONENTS.last
        end
      }
    end
    if COMPONENTS.length > 0 then
      COMPONENTS[0].preset = PRESET_EVENTS
    end
    COMPONENTS.each { |c|
      get_native_events( c )
    }
  end

  get_components_info

  typedef :int, :event_set
  attach_function :PAPI_create_eventset, [:pointer], :int
  attach_function :PAPI_add_event, [:event_set, :int], :int
  attach_function :PAPI_add_named_event, [:event_set, :string], :int
  attach_function :PAPI_remove_event, [:event_set, :int], :int
  attach_function :PAPI_remove_named_event, [:event_set, :string], :int
  attach_function :PAPI_num_events, [:event_set], :int
  attach_function :PAPI_list_events, [:event_set, :pointer, :pointer], :int
  attach_function :PAPI_start, [:event_set], :int
  attach_function :PAPI_stop, [:event_set, :pointer], :int
  attach_function :PAPI_accum, [:event_set, :pointer], :int
  attach_function :PAPI_read, [:event_set, :pointer], :int
  attach_function :PAPI_read_ts, [:event_set, :pointer, :pointer], :int
  attach_function :PAPI_assign_eventset_component, [:event_set, :int], :int
  attach_function :PAPI_get_eventset_component, [:event_set], :int

  class EventSet


    def initialize
      number = FFI::MemoryPointer::new(:int)
      number.write_int(PAPI_NULL)
      error = PAPI::PAPI_create_eventset( number )
      @number = number.read_int
      PAPI::error_check(error)
      @size = 0
    end

    def assign_component(component)
      error = PAPI::PAPI_assign_eventset_component( @number, component.to_i )
      PAPI::error_check(error)
      return self
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

    def possible(preset = true)
      cid = nil
      begin
        e = PAPI::PAPI_get_eventset_component(@number)
        PAPI::error_check(e)
        cid = e
      rescue
        cid = 0
      end
      list = []
      if preset and COMPONENTS[cid].preset then
        events = COMPONENTS[cid].preset
      else
        events = COMPONENTS[cid].native
      end
      events.each { |event|
        error = PAPI::PAPI_add_event(@number, event.to_i)
        if( error >= OK ) then
          error = PAPI::PAPI_remove_event(@number, event.to_i)
          PAPI::error_check(error)
          list.push event
        elsif event.masks then
          event.masks.each { |mask|
            error = PAPI::PAPI_add_named_event(@number, mask.info[:symbol])
            if( error >= OK ) then
              error = PAPI::PAPI_remove_named_event(@number, mask.info[:symbol])
              PAPI::error_check(error)
              list.push event
              break
            end
          }
          event.masks.each { |mask|
            error = PAPI::PAPI_add_named_event(@number, mask.info[:symbol].to_ptr.read_string+":cpu=1")
            if( error >= OK ) then
              error = PAPI::PAPI_remove_named_event(@number, mask.info[:symbol].to_ptr.read_string+":cpu=1")
              PAPI::error_check(error)
              list.push event
              break
            end
          }
        else
          puts (event.info[:symbol].to_ptr.read_string+":PACKAGE0").gsub(/.*::/,"")
          error = PAPI::PAPI_add_named_event(@number, (event.info[:symbol].to_ptr.read_string+":PACKAGE0").gsub(/.*::/,""))
          if( error >= OK ) then
            error = PAPI::PAPI_remove_named_event(@number, (event.info[:symbol].to_ptr.read_string+":PACKAGE0").gsub(/.*::/,""))
            PAPI::error_check(error)
            list.push event
          end
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
  puts set.possible
  puts "-----------"
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
  puts "-----------"
  set = EventSet::new
  puts set.possible(false).length
  if COMPONENTS.length > 1 then
    puts "-----------"
    set = EventSet::new
    set.assign_component(COMPONENTS[1])
    puts COMPONENTS[1].native
    puts set.possible(false)
  end
  
end

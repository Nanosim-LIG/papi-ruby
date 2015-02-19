module PAPI

  MIN_STR_LEN = 64
  MAX_STR_LEN = 128
  MAX_STR_LEN2 = 256
  HUGE_STR_LEN = 1024
  MAX_INFO_TERMS = 12
  PMU_MAX = 40

  OK = 0

  PAPI_NULL = -1

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
  end

  get_events_info

  PRESET_EVENTS.each_index { |i|
    s  = <<EOF
  #{PRESET_EVENTS[i].to_s.gsub("PAPI_","")} = PRESET_EVENTS[#{i}]
EOF
    eval s
  }

end

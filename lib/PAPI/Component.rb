module PAPI

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

    #puts "#{component}: #{component.to_i}"
    #puts component.native.length
    #component.native.each { |evt| puts evt.to_s(true, true) }
  end

  def self.get_components_info
    if VERSION < Version::new(4,0,0,0) then
      info_p = PAPI_get_substrate_info()
      COMPONENTS.push( Component::new(Component::Info::new(info_p)))
      COMPONENTS_HASH[0] = COMPONENTS[0]
    else
      (0...PAPI_num_components()).each { |cid|
        info_p = PAPI_get_component_info(cid)
        info = Component::Info::new(info_p)
        if VERSION >= Version::new(5,0,0,0) and info[:disabled] != 0 then
          #puts "#{info[:name].to_ptr.read_string}: #{info[:disabled_reason].to_ptr.read_string}"
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

end

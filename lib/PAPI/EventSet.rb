module PAPI

  typedef :int, :event_set
  attach_function :PAPI_create_eventset, [:pointer], :int
  attach_function :PAPI_cleanup_eventset, [:event_set], :int
  attach_function :PAPI_destroy_eventset, [:pointer], :int
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

    def cleanup
      error = PAPI::PAPI_cleanup_eventset( @number )
      PAPI::error_check(error)
      return self
    end

    def destroy
      number = FFI::MemoryPointer::new(:int)
      number.write_int(@number)
      error = PAPI::PAPI_destroy_eventset( number )
      @number = number.read_int
      PAPI::error_check(error)
      return self
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

    def add_named(events)
      evts = [events].flatten
      evts.each { |ev|
        error = PAPI::PAPI_add_named_event(@number, ev.to_s)
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

    def remove_named( events )
      evts = [events].flatten
      evts.each { |ev|
        error = PAPI::PAPI_remove_named_event(@number, ev.to_s)
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
          error = PAPI::PAPI_add_named_event(@number, (event.info[:symbol].to_ptr.read_string+":cpu=1").gsub(/.*::/,""))
          if( error >= OK ) then
            error = PAPI::PAPI_remove_named_event(@number, (event.info[:symbol].to_ptr.read_string+":cpu=1").gsub(/.*::/,""))
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

end

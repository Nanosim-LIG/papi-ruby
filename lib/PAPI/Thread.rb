module PAPI
  attach_function :PAPI_thread_init, [:pointer], :int
  attach_function :PAPI_register_thread, [], :int
  attach_function :PAPI_unregister_thread, [], :int
  attach_function :PAPI_list_threads, [:pointer, :pointer], :int

  def self.thread_init(pointer = nil)
    pointer = PAPI.ffi_libraries.first.find_function("pthread_self") unless pointer
    err = PAPI.PAPI_thread_init(pointer)
    error_check(err)
    return self
  end

  def self.register_thread
    err = PAPI.PAPI_register_thread
    error_check(err)
    return self
  end

  def self.unregister_thread
    err = PAPI.PAPI_unregister_thread
    error_check(err)
    return self
  end

  def self.list_threads
    count_p = FFI::MemoryPointer::new(:int)
    err = PAPI.PAPI_list_threads(nil, count_p)
    error_check(err)
    count = count_p.read_int
    return [] if count == 0
    id_p = FFI::MemoryPointer::new(:ulong, count)
    err = PAPI.PAPI_list_threads(id_p, count_p)
    error_check(err)
    return id_p.read_array_of_ulong(count)
  end

end

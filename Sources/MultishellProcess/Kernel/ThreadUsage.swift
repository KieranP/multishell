import Darwin

/// One thread of this process: its name, whether it is the main thread, and
/// the CPU time it has spent since it started.
public struct ThreadUsage: Sendable, Equatable {
  private static let nameCapacity = 64

  /// The kernel's id for the thread, stable for its life and never reused
  /// while it runs, unlike its port name.
  public let id: UInt64
  /// Empty where the thread was never named.
  public let name: String
  public let isMain: Bool
  public let cpuTime: Duration

  /// The calling thread's `id`: read on the main thread, what `ofThisProcess`
  /// is handed, the SDK having no public way to name the main thread from another.
  public static func currentThreadID() -> UInt64 {
    var id: UInt64 = 0
    pthread_threadid_np(nil, &id)
    return id
  }

  /// Every thread running at the moment of the read.
  public static func ofThisProcess(mainThreadID: UInt64) -> [Self] {
    var threads: thread_act_array_t?
    var count: mach_msg_type_number_t = 0
    guard task_threads(mach_task_self_, &threads, &count) == KERN_SUCCESS, let threads else {
      return []
    }
    defer {
      for index in 0..<Int(count) { mach_port_deallocate(mach_task_self_, threads[index]) }
      vm_deallocate(
        mach_task_self_,
        vm_address_t(UInt(bitPattern: threads)),
        vm_size_t(Int(count) * MemoryLayout<thread_act_t>.stride),
      )
    }
    return (0..<Int(count)).compactMap { index in
      usage(of: threads[index], mainThreadID: mainThreadID)
    }
  }

  private static func usage(of thread: thread_act_t, mainThreadID: UInt64) -> Self? {
    guard let basic: thread_basic_info = info(of: thread, flavor: THREAD_BASIC_INFO),
      let identifier: thread_identifier_info = info(of: thread, flavor: THREAD_IDENTIFIER_INFO)
    else { return nil }
    let cpuTime = duration(of: basic.user_time) + duration(of: basic.system_time)
    return Self(
      id: identifier.thread_id,
      name: name(of: thread),
      isMain: identifier.thread_id == mainThreadID,
      cpuTime: cpuTime,
    )
  }

  private static func info<Info>(of thread: thread_act_t, flavor: Int32) -> Info? {
    let pointer = UnsafeMutablePointer<Info>.allocate(capacity: 1)
    defer { pointer.deallocate() }
    var count = mach_msg_type_number_t(MemoryLayout<Info>.size / MemoryLayout<natural_t>.size)
    let result = pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
      infoPointer in
      thread_info(thread, thread_flavor_t(flavor), infoPointer, &count)
    }
    return result == KERN_SUCCESS ? pointer.pointee : nil
  }

  private static func name(of thread: thread_act_t) -> String {
    guard let pthread = pthread_from_mach_thread_np(thread) else { return "" }
    var buffer = [CChar](repeating: 0, count: nameCapacity)
    guard pthread_getname_np(pthread, &buffer, buffer.count) == 0 else { return "" }
    return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
  }

  private static func duration(of time: time_value_t) -> Duration {
    .seconds(Int64(time.seconds)) + .microseconds(Int64(time.microseconds))
  }
}

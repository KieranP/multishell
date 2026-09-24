import Foundation

/// Waits for a pipe's input or its writer's exit, whichever comes first: the
/// pipe reaches EOF only once every child that inherited it has closed it too.
public final class InputOrExitWatch {
  public enum Event: Sendable { case input, exited }

  private let descriptor: Int32
  private let pid: pid_t
  #if !os(Linux)
    private let queue: Int32
    private var alreadyExited = false
  #endif

  public init?(descriptor: Int32, pid: pid_t) {
    guard pid > 0 else { return nil }
    self.descriptor = descriptor
    self.pid = pid
    #if !os(Linux)
      // Stored last: once every property is set, a failed init runs deinit,
      // which would close the descriptor a second time.
      let watching = kqueue()
      guard watching >= 0 else { return nil }
      var read = kevent(
        ident: UInt(descriptor), filter: Int16(EVFILT_READ), flags: UInt16(EV_ADD), fflags: 0,
        data: 0, udata: nil)
      guard kevent(watching, &read, 1, nil, 0, nil) == 0 else {
        close(watching)
        return nil
      }
      var exit = kevent(
        ident: UInt(pid), filter: Int16(EVFILT_PROC), flags: UInt16(EV_ADD | EV_ONESHOT),
        fflags: UInt32(NOTE_EXIT), data: 0, udata: nil)
      if kevent(watching, &exit, 1, nil, 0, nil) != 0 {
        guard errno == ESRCH else {
          close(watching)
          return nil
        }
        alreadyExited = true
      }
      queue = watching
    #endif
  }

  #if !os(Linux)
    private typealias KernelEvent = Darwin.kevent
  #endif

  deinit {
    #if !os(Linux)
      close(queue)
    #endif
  }

  /// Blocks until the descriptor is readable, EOF included, or the process
  /// has gone. An exit is reported first when both are due.
  public func next() -> Event {
    #if os(Linux)
      // No process descriptor to wait on here, so the exit is looked for each second.
      var entry = pollfd(fd: descriptor, events: Int16(POLLIN), revents: 0)
      while true {
        let ready = poll(&entry, 1, 1000)
        if ready > 0 { return .input }
        if ready < 0, errno != EINTR { return .exited }
        if ProcessAncestry.isGone(pid) { return .exited }
      }
    #else
      if alreadyExited { return .exited }
      var events: [KernelEvent] = Array(repeating: KernelEvent(), count: 2)
      while true {
        let count = kevent(queue, nil, 0, &events, Int32(events.count), nil)
        if count < 0, errno == EINTR { continue }
        guard count > 0 else { return .exited }
        if events.prefix(Int(count)).contains(where: { $0.filter == Int16(EVFILT_PROC) }) {
          alreadyExited = true
          return .exited
        }
        return .input
      }
    #endif
  }

  /// What the pipe holds now, without waiting for more.
  public func drain() -> Data {
    let flags = fcntl(descriptor, F_GETFL)
    _ = fcntl(descriptor, F_SETFL, flags | O_NONBLOCK)
    var drained = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while case let count = read(descriptor, &buffer, buffer.count), count > 0 {
      drained.append(contentsOf: buffer.prefix(count))
    }
    return drained
  }
}

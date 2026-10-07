import Foundation

/// Waits for a pipe's input or its writer's exit, whichever comes first: the
/// pipe reaches EOF only once every child that inherited it has closed it too.
public final class InputOrExitWatch {
  public enum Event: Sendable { case input, exited }

  private let descriptor: Int32
  private let kqueueDescriptor: Int32
  private var hasExited = false

  public init?(descriptor: Int32, pid: pid_t) {
    guard pid > 0 else { return nil }
    self.descriptor = descriptor
    let queue = kqueue()
    guard queue >= 0 else { return nil }
    var readFilter = kevent(
      ident: UInt(descriptor), filter: Int16(EVFILT_READ), flags: UInt16(EV_ADD), fflags: 0,
      data: 0, udata: nil)
    guard kevent(queue, &readFilter, 1, nil, 0, nil) == 0 else {
      close(queue)
      return nil
    }
    var exitFilter = kevent(
      ident: UInt(pid), filter: Int16(EVFILT_PROC), flags: UInt16(EV_ADD | EV_ONESHOT),
      fflags: UInt32(NOTE_EXIT), data: 0, udata: nil)
    if kevent(queue, &exitFilter, 1, nil, 0, nil) != 0 {
      guard errno == ESRCH else {
        close(queue)
        return nil
      }
      hasExited = true
    }
    // Stored last: once every property is set, a failed init runs deinit,
    // which would close the descriptor a second time.
    kqueueDescriptor = queue
  }

  private typealias KernelEvent = Darwin.kevent

  deinit {
    close(kqueueDescriptor)
  }

  /// Blocks until the descriptor is readable, EOF included, or the process
  /// has gone. An exit is reported first when both are due.
  public func next() -> Event {
    if hasExited { return .exited }
    var events: [KernelEvent] = Array(repeating: KernelEvent(), count: 2)
    while true {
      let count = kevent(kqueueDescriptor, nil, 0, &events, Int32(events.count), nil)
      if count < 0, errno == EINTR { continue }
      guard count > 0 else { return .exited }
      if events.prefix(Int(count)).contains(where: { $0.filter == Int16(EVFILT_PROC) }) {
        hasExited = true
        return .exited
      }
      return .input
    }
  }

  /// What the pipe holds now, without waiting for more.
  public func drain() -> Data {
    DescriptorFlags.setNonBlocking(descriptor)
    var drained = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while case let count = read(descriptor, &buffer, buffer.count), count > 0 {
      drained.append(contentsOf: buffer.prefix(count))
    }
    return drained
  }
}

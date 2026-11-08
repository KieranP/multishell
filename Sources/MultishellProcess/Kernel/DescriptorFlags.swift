import Foundation

enum DescriptorFlags {
  static func setNonBlocking(_ descriptor: Int32) {
    let flags = fcntl(descriptor, F_GETFL)
    _ = fcntl(descriptor, F_SETFL, flags | O_NONBLOCK)
  }

  /// libghostty forks a pane's shell with no descriptor sweep, so one left open
  /// across exec lives as long as the shell does.
  static func setClosesOnExec(_ descriptor: Int32) {
    _ = fcntl(descriptor, F_SETFD, FD_CLOEXEC)
  }
}

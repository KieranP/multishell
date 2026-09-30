import Foundation

extension UnixSocketServer {
  /// What a failed `accept` means. Every case but `waitForNextEvent` leaves
  /// the connection in the backlog, and the read source fires again on it.
  enum AcceptOutcome: Equatable {
    case waitForNextEvent
    case again
    case outOfDescriptors

    init(errno code: Int32) {
      switch code {
      case EINTR, ECONNABORTED, EPROTO: self = .again
      case EMFILE, ENFILE, ENOBUFS, ENOMEM: self = .outOfDescriptors
      default: self = .waitForNextEvent
      }
    }
  }
}

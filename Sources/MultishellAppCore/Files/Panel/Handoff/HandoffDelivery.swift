/// How writing a Send's file and pasting its mention went.
enum HandoffDelivery: Equatable, Sendable {
  case delivered
  /// The pane took no paste: it closed, or its shell has not started.
  case notPasted
  /// The file could not be written; its error was presented.
  case notWritten
}

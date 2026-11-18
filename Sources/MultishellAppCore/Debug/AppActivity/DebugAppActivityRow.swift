/// A row of App Activity: one kind of the app's own work over the range.
public struct DebugAppActivityRow: Sendable, Equatable, Identifiable {
  public enum Kind: Sendable, Hashable {
    /// Each report the socket brought, handled on the main actor.
    case stateReports
    /// Each `state.json` written, encoded and saved off the main actor.
    case stateSaves
  }

  let kind: Kind
  let tally: DebugWorkTally

  public var id: Kind { kind }

  /// `nil` for reports, which write nothing.
  var bytesWritten: UInt64? { kind == .stateSaves ? tally.bytesWritten : nil }
}

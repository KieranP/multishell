import Foundation
import MultishellCore

@testable import MultishellAppCore

extension SessionStates {
  var states: [Key: SessionState] { entries.compactMapValues(\.state) }
  var pids: [Key: Int32] { entries.compactMapValues(\.pid) }
  var sinceDates: [Key: Date] { entries.compactMapValues(\.since) }
  var notes: [Key: SessionNote] { entries.compactMapValues(\.note) }

  /// Nothing showing and nothing out. A stamp and a note outlive the state
  /// they were about, so neither counts; a roster does.
  var showsNothing: Bool {
    !entries.values.contains { $0.state != nil || !$0.roster.subagents.isEmpty }
  }
}

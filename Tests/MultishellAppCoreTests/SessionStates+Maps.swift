import Foundation
import MultishellCore

@testable import MultishellAppCore

extension SessionStates {
  var states: [Key: SessionState] { entries.compactMapValues(\.state) }
  var pids: [Key: Int32] { entries.compactMapValues(\.pid) }
  var sinceDates: [Key: Date] { entries.compactMapValues(\.since) }
  var notes: [Key: SessionNote] { entries.compactMapValues(\.note) }
}

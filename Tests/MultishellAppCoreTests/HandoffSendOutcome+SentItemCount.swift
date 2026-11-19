@testable import MultishellAppCore

extension HandoffSendOutcome {
  /// How many items went, `nil` for a Send that sent nothing.
  var sentItemCount: Int? {
    if case .sent(let itemCount, _) = self { itemCount } else { nil }
  }
}

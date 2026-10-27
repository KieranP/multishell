import Foundation
import MultishellCore
import MultishellServices

/// A service read that failed, and how old the answer still shown is.
struct ServiceReadProblem: Equatable, Sendable {
  let integration: ServiceIntegration
  let failure: ServiceReadFailure
  /// When the shown answer was read, `nil` where none ever was.
  let lastAnsweredAt: Date?
}

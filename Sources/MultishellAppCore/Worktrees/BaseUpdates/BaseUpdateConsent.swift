/// What the user, or a command line's flags, agreed an update may run over; a
/// reason found later that they did not agree to asks, or refuses, again.
struct BaseUpdateConsent: Equatable, Sendable {
  var overWorkingAgent = false
  var rewritingPushedBranch = false
}

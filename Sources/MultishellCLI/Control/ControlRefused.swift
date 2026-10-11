import MultishellCore

/// The app's refusal, thrown so a command that reads the output need not
/// check for one at every step; it exits 1 with the wording.
struct ControlRefused: Error, CustomStringConvertible {
  let refusal: ControlRefusal

  var description: String { refusal.wording }
}

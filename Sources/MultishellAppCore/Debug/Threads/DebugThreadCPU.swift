/// The app's CPU over one sample split by thread: the main thread's and the
/// terminals' shares, and the time each kind of thread spent.
struct DebugThreadCPU: Sendable, Equatable {
  static let unmeasured = Self(mainPercent: 0, terminalsPercent: 0, byThread: [:])

  let mainPercent: Double
  let terminalsPercent: Double
  let byThread: [DebugThreadKey: DebugThreadTally]
}

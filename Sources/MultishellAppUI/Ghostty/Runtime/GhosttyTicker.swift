import Foundation

/// What libghostty's wakeup reaches. It can fire on any thread and before the
/// app it wakes exists, so the runtime is attached once it does.
@MainActor
final class GhosttyTicker {
  weak var runtime: GhosttyRuntime?

  var userdata: UnsafeMutableRawPointer { Unmanaged.passUnretained(self).toOpaque() }

  nonisolated static func wakeUp(_ userdata: UnsafeMutableRawPointer?) {
    guard let userdata else { return }
    let ticker = Unmanaged<GhosttyTicker>.fromOpaque(userdata).takeUnretainedValue()
    Task { @MainActor in ticker.runtime?.tick() }
  }
}

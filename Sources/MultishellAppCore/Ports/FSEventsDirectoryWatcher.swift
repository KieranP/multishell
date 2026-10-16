import Foundation
import MultishellCore

/// `DirectoryWatcher` on FSEvents, Darwin only: one stream over every
/// directory and everything beneath it, so no subdirectory needs a watch of its own.
@MainActor
public final class FSEventsDirectoryWatcher: DirectoryWatcher {
  /// How long FSEvents gathers a burst before handing it over.
  private static let latency: TimeInterval = 0.15

  public var onChange: (@MainActor ([URL]) -> Void)?

  private var stream: FileEventStream?
  /// Bumped by every `watch` and `stop`, so a stream started for an earlier
  /// call is torn down rather than installed.
  private var generation = 0
  /// Bumped by `stop` alone. A batch from the stream being replaced still
  /// counts: the new one starts after it and would never report that change.
  private var stops = 0
  private let resolve: @Sendable ([URL]) -> WatchedDirectories

  public convenience init() {
    self.init { WatchedDirectories($0) }
  }

  init(resolving resolve: @escaping @Sendable ([URL]) -> WatchedDirectories) {
    self.resolve = resolve
  }

  /// Paths are resolved and the stream started off the main actor: a
  /// repository on a stalled mount would hold the window until it timed out.
  public func watch(_ directories: [URL]) async {
    generation += 1
    let generation = generation
    let stops = stops
    let resolve = resolve
    let latency = Self.latency
    let deliver: @Sendable ([URL]) -> Void = { [weak self] changed in
      DispatchQueue.main.async {
        MainActor.assumeIsolated { self?.deliver(changed, startedAfterStops: stops) }
      }
    }
    let started = await runOnDispatch {
      FileEventStream(
        watched: resolve(directories),
        latency: latency,
        onChange: deliver,
      )
    }
    guard generation == self.generation else {
      started?.invalidate()
      return
    }
    stream?.invalidate()
    stream = started
  }

  public func stop() {
    generation += 1
    stops += 1
    stream?.invalidate()
    stream = nil
  }

  private func deliver(_ changed: [URL], startedAfterStops stops: Int) {
    guard stops == self.stops else { return }
    onChange?(changed)
  }
}

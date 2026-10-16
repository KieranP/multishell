import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore

/// A real FSEvents watcher plus a marker directory: FSEvents delivers in order,
/// so once a marker arrives, everything written before it has too.
@MainActor
final class RealWatcherProbe {
  private let watcher = FSEventsDirectoryWatcher()
  private let marker: URL
  private let batches = Recorder<[URL]>()

  init(watching directories: [URL]) async throws {
    marker = try Scratch.directory("marker")
    await watcher.watch(directories + [marker])
    watcher.onChange = { [batches] in batches.record($0) }
  }

  /// What changed under the watched directories while `work` ran, and nothing
  /// from before it.
  func changes(during work: () async throws -> Void) async throws -> [URL] {
    try await markAndWait()
    batches.clear()
    try await work()
    try await markAndWait()
    return batches.received.joined().filter { $0.pathComponents(under: marker) == nil }
  }

  func stop() {
    watcher.stop()
    Scratch.remove(marker)
  }

  private func markAndWait() async throws {
    let mark = marker.appending(path: UUID().uuidString)
    try "x".write(to: mark, atomically: true, encoding: .utf8)
    try await waitUntil({ self.hasReceived(mark) }, seconds: 30)
    #expect(hasReceived(mark), "the watcher delivered nothing")
  }

  private func hasReceived(_ url: URL) -> Bool {
    batches.received.joined().contains { $0.standardizedFileURL == url.standardizedFileURL }
  }
}

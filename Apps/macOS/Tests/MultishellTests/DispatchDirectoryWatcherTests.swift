import Foundation
import Testing

@testable import Multishell

/// The kqueue watcher is the only file-event code in the app. These wait on
/// real filesystem events, so they carry a timeout rather than a fixed sleep.
@Suite(.serialized) @MainActor
struct DispatchDirectoryWatcherTests {
  private func scratch() throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("multishell-watch-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  /// Resolves when `onChange` fires, or after `seconds`.
  private func nextChange(
    of watcher: DispatchDirectoryWatcher, within seconds: Double = 3
  ) async -> Bool {
    await withCheckedContinuation { continuation in
      var done = false
      watcher.onChange = {
        guard !done else { return }
        done = true
        continuation.resume(returning: true)
      }
      Task { @MainActor in
        try? await Task.sleep(for: .seconds(seconds))
        guard !done else { return }
        done = true
        continuation.resume(returning: false)
      }
    }
  }

  @Test func aFileCreatedInAWatchedDirectoryFires() async throws {
    let dir = try scratch()
    defer { try? FileManager.default.removeItem(at: dir) }
    let watcher = DispatchDirectoryWatcher()
    watcher.watch([dir])
    defer { watcher.stop() }

    async let fired = nextChange(of: watcher)
    try "x".write(to: dir.appendingPathComponent("new.txt"), atomically: true, encoding: .utf8)

    #expect(await fired)
  }

  @Test func burstsAreCoalescedIntoOneCallback() async throws {
    let dir = try scratch()
    defer { try? FileManager.default.removeItem(at: dir) }
    let watcher = DispatchDirectoryWatcher()
    watcher.watch([dir])
    defer { watcher.stop() }
    var calls = 0
    watcher.onChange = { calls += 1 }

    for i in 0..<20 {
      try "x".write(to: dir.appendingPathComponent("f\(i)"), atomically: true, encoding: .utf8)
    }
    try await Task.sleep(for: .seconds(1.2))

    #expect(calls == 1)
  }

  @Test func replacingTheWatchedSetStopsOldDirectoriesAndKeepsMissingOnesOut() async throws {
    let a = try scratch()
    let b = try scratch()
    defer {
      try? FileManager.default.removeItem(at: a)
      try? FileManager.default.removeItem(at: b)
    }
    let watcher = DispatchDirectoryWatcher()
    watcher.watch([a, URL(fileURLWithPath: "/definitely/not/here")])
    watcher.watch([b])
    defer { watcher.stop() }

    async let firedForA = nextChange(of: watcher, within: 1)
    try "x".write(to: a.appendingPathComponent("ignored"), atomically: true, encoding: .utf8)
    #expect(await firedForA == false)

    async let firedForB = nextChange(of: watcher)
    try "x".write(to: b.appendingPathComponent("seen"), atomically: true, encoding: .utf8)
    #expect(await firedForB)
  }

  @Test func stopSilencesTheWatcher() async throws {
    let dir = try scratch()
    defer { try? FileManager.default.removeItem(at: dir) }
    let watcher = DispatchDirectoryWatcher()
    watcher.watch([dir])
    watcher.stop()

    async let fired = nextChange(of: watcher, within: 1)
    try "x".write(to: dir.appendingPathComponent("after-stop"), atomically: true, encoding: .utf8)

    #expect(await fired == false)
  }
}

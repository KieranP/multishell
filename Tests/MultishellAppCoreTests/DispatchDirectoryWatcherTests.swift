#if canImport(Darwin)
  import Foundation
  import Testing

  @testable import MultishellAppCore

  /// The kqueue watcher is the only file-event code in the app. These wait
  /// on real filesystem events, so they carry a timeout rather than a fixed
  /// sleep.
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

    /// Every refresh re-arms the watcher with the current directory set.
    /// Each source holds a descriptor until its cancel handler runs; a
    /// mistake there would exhaust the process after a day of ticks.
    @Test func rearmingRepeatedlyDoesNotLeakDescriptors() async throws {
      let dirs = try (0..<4).map { _ in try scratch() }
      defer {
        for dir in dirs { try? FileManager.default.removeItem(at: dir) }
      }
      func lowestDescriptorCount(over samples: Int) async throws -> Int {
        var lowest = Int.max
        for _ in 0..<samples {
          lowest = min(
            lowest, try FileManager.default.contentsOfDirectory(atPath: "/dev/fd").count)
          try await Task.sleep(for: .milliseconds(30))
        }
        return lowest
      }
      let watcher = DispatchDirectoryWatcher()
      watcher.watch(dirs)
      let before = try await lowestDescriptorCount(over: 4)

      for round in 0..<200 {
        // Alternate between the full set, a subset, and a set with a missing
        // directory, so sources are created, kept, cancelled and skipped.
        switch round % 3 {
        case 0: watcher.watch(dirs)
        case 1: watcher.watch(Array(dirs.prefix(2)))
        default: watcher.watch([dirs[3], URL(fileURLWithPath: "/definitely/not/here")])
        }
      }
      watcher.watch(dirs)

      let after = try await lowestDescriptorCount(over: 8)
      #expect(
        after - before < 20, "before \(before), after \(after); each round moved 2 to 4 sources")
      watcher.stop()
    }

    @Test func stopSilencesTheWatcher() async throws {
      let dir = try scratch()
      defer { try? FileManager.default.removeItem(at: dir) }
      let watcher = DispatchDirectoryWatcher()
      watcher.watch([dir])
      watcher.stop()

      async let fired = nextChange(of: watcher, within: 1)
      try "x".write(
        to: dir.appendingPathComponent("after-stop"), atomically: true, encoding: .utf8)

      #expect(await fired == false)
    }
  }
#endif

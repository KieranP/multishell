#if canImport(Darwin)
  import Foundation
  import TestScratch
  import Testing

  @testable import MultishellAppCore

  /// The kqueue watcher is the only file-event code in the app. These wait
  /// on real filesystem events, so they carry a timeout rather than a fixed
  /// sleep.
  @Suite(.serialized) @MainActor
  struct DispatchDirectoryWatcherTests {
    private func scratch() throws -> URL {
      try Scratch.directory("watch")
    }

    /// Counts the watcher's callbacks from the moment it is made.
    ///
    /// Made before the change it is counting, never after: the watcher
    /// coalesces and delivers once, so a callback that lands while nobody is
    /// listening is gone, and nothing touches the directory a second time.
    /// Awaiting an `async let` around the change was that mistake, and it
    /// cost a whole test run on a runner where the callback won the race.
    private func changes(of watcher: DispatchDirectoryWatcher) -> Changes {
      let changes = Changes()
      watcher.onChange = { changes.count += 1 }
      return changes
    }

    @MainActor final class Changes {
      var count = 0

      /// Whether a callback has arrived, waiting up to `seconds` for one.
      /// The wait is far above the watcher's 400 ms coalesce because both the
      /// event and this loop land on the main actor, which the rest of the
      /// suite is also using; a busy runner has taken over ten seconds to
      /// deliver.
      func arrived(within seconds: Double = 30) async -> Bool {
        let deadline = ContinuousClock.now + .seconds(seconds)
        while count == 0, ContinuousClock.now < deadline {
          try? await Task.sleep(for: .milliseconds(20))
        }
        return count > 0
      }
    }

    @Test func aFileCreatedInAWatchedDirectoryFires() async throws {
      let dir = try scratch()
      defer { try? FileManager.default.removeItem(at: dir) }
      let watcher = DispatchDirectoryWatcher()
      watcher.watch([dir])
      defer { watcher.stop() }

      let changed = changes(of: watcher)
      try "x".write(to: dir.appendingPathComponent("new.txt"), atomically: true, encoding: .utf8)

      #expect(await changed.arrived())
    }

    /// `git worktree remove foo` then `git worktree add ... foo` inside one
    /// coalesce window: the path stays wanted, but the descriptor is left on
    /// the unlinked inode and never fires again.
    @Test func aDirectoryDeletedAndRemadeAtOnePathIsWatchedAgain() async throws {
      let parent = try scratch()
      defer { try? FileManager.default.removeItem(at: parent) }
      let dir = parent.appendingPathComponent("worktree", isDirectory: true)
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

      let watcher = DispatchDirectoryWatcher()
      watcher.watch([dir])
      defer { watcher.stop() }

      try FileManager.default.removeItem(at: dir)
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
      // The rearm the app does once its own watch fires; the path is still
      // wanted, so nothing here asks for a new source outright.
      watcher.watch([dir])
      // The unlink fires the old source, and that callback is what this test
      // counted at first: it arrived and said nothing about the new directory.
      // Waited out against a nil handler, so what is counted next is the file.
      try? await Task.sleep(for: .milliseconds(900))

      let changed = changes(of: watcher)
      try "x".write(to: dir.appendingPathComponent("new.txt"), atomically: true, encoding: .utf8)

      #expect(await changed.arrived(), "the source is still on the unlinked inode")
    }

    @Test func burstsAreCoalescedIntoOneCallback() async throws {
      let dir = try scratch()
      defer { try? FileManager.default.removeItem(at: dir) }
      let watcher = DispatchDirectoryWatcher()
      watcher.watch([dir])
      defer { watcher.stop() }

      let changed = changes(of: watcher)
      for i in 0..<20 {
        try "x".write(to: dir.appendingPathComponent("f\(i)"), atomically: true, encoding: .utf8)
      }

      #expect(await changed.arrived(), "the burst arrived")
      try await Task.sleep(for: .seconds(1))
      #expect(changed.count == 1, "as one callback")
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

      let forA = changes(of: watcher)
      try "x".write(to: a.appendingPathComponent("ignored"), atomically: true, encoding: .utf8)
      #expect(await forA.arrived(within: 1) == false)

      let forB = changes(of: watcher)
      try "x".write(to: b.appendingPathComponent("seen"), atomically: true, encoding: .utf8)
      #expect(await forB.arrived())
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

      let changed = changes(of: watcher)
      try "x".write(
        to: dir.appendingPathComponent("after-stop"), atomically: true, encoding: .utf8)

      #expect(await changed.arrived(within: 1) == false)
    }
  }
#endif

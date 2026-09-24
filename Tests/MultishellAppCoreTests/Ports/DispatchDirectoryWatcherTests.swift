#if canImport(Darwin)
  import Foundation
  import TestScratch
  import Testing

  @testable import MultishellAppCore

  @Suite(.serialized) @MainActor
  struct DispatchDirectoryWatcherTests {
    private func scratch() throws -> URL {
      try Scratch.directory("watch")
    }

    /// Call before the change: the watcher delivers once per coalesced burst, so a
    /// callback with no listener is lost. An `async let` around the change lost that race.
    private func changes(of watcher: DispatchDirectoryWatcher) -> Changes {
      let changes = Changes()
      watcher.onChange = { _ in changes.count += 1 }
      return changes
    }

    @MainActor final class Changes {
      var count = 0

      /// The event and this loop share a busy main actor, so the wait is far above the
      /// 400 ms coalesce; a loaded runner has taken over ten seconds to deliver.
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
      await watcher.watch([dir])
      defer { watcher.stop() }

      let changed = changes(of: watcher)
      try "x".write(to: dir.appendingPathComponent("new.txt"), atomically: true, encoding: .utf8)

      #expect(await changed.arrived())
    }

    /// `git worktree remove foo` then `add ... foo` inside one coalesce window keeps the
    /// path wanted but leaves the descriptor on the unlinked inode, never firing again.
    @Test func aDirectoryDeletedAndRemadeAtOnePathIsWatchedAgain() async throws {
      let parent = try scratch()
      defer { try? FileManager.default.removeItem(at: parent) }
      let dir = parent.appendingPathComponent("worktree", isDirectory: true)
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

      let watcher = DispatchDirectoryWatcher()
      await watcher.watch([dir])
      defer { watcher.stop() }

      try FileManager.default.removeItem(at: dir)
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
      // The rearm the app does once its own watch fires; the path is still
      // wanted, so nothing here asks for a new source outright.
      await watcher.watch([dir])
      // The unlink fires the old source, which once passed this test by itself; waiting
      // it out against a nil handler leaves the file as the next thing counted.
      try? await Task.sleep(for: .milliseconds(900))

      let changed = changes(of: watcher)
      try "x".write(to: dir.appendingPathComponent("new.txt"), atomically: true, encoding: .utf8)

      #expect(await changed.arrived(), "the source is still on the unlinked inode")
    }

    @Test func burstsAreCoalescedIntoOneCallback() async throws {
      let dir = try scratch()
      defer { try? FileManager.default.removeItem(at: dir) }
      let watcher = DispatchDirectoryWatcher()
      await watcher.watch([dir])
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
      await watcher.watch([a, URL(fileURLWithPath: "/definitely/not/here")])
      await watcher.watch([b])
      defer { watcher.stop() }

      let forA = changes(of: watcher)
      try "x".write(to: a.appendingPathComponent("ignored"), atomically: true, encoding: .utf8)
      #expect(await forA.arrived(within: 1) == false)

      let forB = changes(of: watcher)
      try "x".write(to: b.appendingPathComponent("seen"), atomically: true, encoding: .utf8)
      #expect(await forB.arrived())
    }

    /// Every refresh re-arms the watcher and each source holds a descriptor until its
    /// cancel handler runs, so a leak there exhausts the process within a day of ticks.
    @Test func rearmingRepeatedlyDoesNotLeakDescriptors() async throws {
      let dirs = try (0..<4).map { _ in try scratch() }
      defer {
        for dir in dirs { try? FileManager.default.removeItem(at: dir) }
      }
      let watcher = DispatchDirectoryWatcher()
      await watcher.watch(dirs)
      let before = try await lowestDescriptorCount(
        over: .milliseconds(120), every: .milliseconds(30))

      for round in 0..<200 {
        // Alternate between the full set, a subset, and a set with a missing
        // directory, so sources are created, kept, cancelled and skipped.
        switch round % 3 {
        case 0: await watcher.watch(dirs)
        case 1: await watcher.watch(Array(dirs.prefix(2)))
        default: await watcher.watch([dirs[3], URL(fileURLWithPath: "/definitely/not/here")])
        }
      }
      await watcher.watch(dirs)

      let after = try await lowestDescriptorCount(
        over: .milliseconds(240), every: .milliseconds(30))
      #expect(
        after - before < 20, "before \(before), after \(after); each round moved 2 to 4 sources")
      watcher.stop()
    }

    @Test func directoriesAreOpenedOffTheMainThread() async throws {
      let dir = try scratch()
      defer { try? FileManager.default.removeItem(at: dir) }
      let onMain = LineRecorder()
      let watcher = DispatchDirectoryWatcher { path in
        onMain.record(Thread.isMainThread ? "main" : "off")
        return open(path, O_EVTONLY)
      }
      defer { watcher.stop() }

      await watcher.watch([dir])

      #expect(onMain.received == ["off"])
    }

    @Test func aWatchSupersededWhileItsDirectoriesOpenedArmsNothing() async throws {
      let a = try scratch()
      let b = try scratch()
      defer {
        try? FileManager.default.removeItem(at: a)
        try? FileManager.default.removeItem(at: b)
      }
      let opened = LineRecorder()
      let gate = DispatchSemaphore(value: 0)
      let watcher = DispatchDirectoryWatcher { path in
        opened.record(path)
        if path == a.standardizedFileURL.path { gate.wait() }
        return open(path, O_EVTONLY)
      }
      defer { watcher.stop() }

      let first = Task { await watcher.watch([a]) }
      try await waitUntil { !opened.received.isEmpty }
      await watcher.watch([b])
      gate.signal()
      await first.value

      let forA = changes(of: watcher)
      try "x".write(to: a.appendingPathComponent("ignored"), atomically: true, encoding: .utf8)
      #expect(await forA.arrived(within: 1) == false)
    }

    @Test func stopSilencesTheWatcher() async throws {
      let dir = try scratch()
      defer { try? FileManager.default.removeItem(at: dir) }
      let watcher = DispatchDirectoryWatcher()
      await watcher.watch([dir])
      watcher.stop()

      let changed = changes(of: watcher)
      try "x".write(
        to: dir.appendingPathComponent("after-stop"), atomically: true, encoding: .utf8)

      #expect(await changed.arrived(within: 1) == false)
    }
  }
#endif

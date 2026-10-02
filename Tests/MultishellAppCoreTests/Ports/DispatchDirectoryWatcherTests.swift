import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite(.serialized) @MainActor
struct DispatchDirectoryWatcherTests {
  /// Call before the change: the watcher delivers once per coalesced burst, so a
  /// callback with no listener is lost. An `async let` around the change lost that race.
  private func changes(of watcher: DispatchDirectoryWatcher) -> Recorder<[URL]> {
    let changes = Recorder<[URL]>()
    watcher.onChange = { changes.record($0) }
    return changes
  }

  /// The event and the wait share a busy main actor, so this is far above the
  /// 400 ms coalesce; a loaded runner has taken over ten seconds to deliver.
  private let deliveryBound: Double = 30

  @Test func aFileCreatedInAWatchedDirectoryFires() async throws {
    let directory = try Scratch.directory("watch")
    defer { Scratch.remove(directory) }
    let watcher = DispatchDirectoryWatcher()
    await watcher.watch([directory])
    defer { watcher.stop() }

    let changed = changes(of: watcher)
    try "x".write(
      to: directory.appendingPathComponent("new.txt"), atomically: true, encoding: .utf8)

    try await waitUntil({ changed.received.count > 0 }, seconds: deliveryBound)
    #expect(changed.received.count > 0)
  }

  /// `git worktree remove foo` then `add ... foo` inside one coalesce window keeps the
  /// path wanted but leaves the descriptor on the unlinked inode, never firing again.
  @Test func aDirectoryDeletedAndRemadeAtOnePathIsWatchedAgain() async throws {
    let parent = try Scratch.directory("watch")
    defer { Scratch.remove(parent) }
    let directory = parent.appendingPathComponent("worktree", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let watcher = DispatchDirectoryWatcher()
    await watcher.watch([directory])
    defer { watcher.stop() }

    try FileManager.default.removeItem(at: directory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    // The rearm the app does once its own watch fires; the path is still
    // wanted, so nothing here asks for a new source outright.
    await watcher.watch([directory])
    // The unlink fires the old source, which once passed this test by itself; waiting
    // it out against a nil handler leaves the file as the next thing counted.
    try? await Task.sleep(for: .milliseconds(900))

    let changed = changes(of: watcher)
    try "x".write(
      to: directory.appendingPathComponent("new.txt"), atomically: true, encoding: .utf8)

    try await waitUntil({ changed.received.count > 0 }, seconds: deliveryBound)
    #expect(changed.received.count > 0, "the source is still on the unlinked inode")
  }

  @Test func burstsAreCoalescedIntoOneCallback() async throws {
    let directory = try Scratch.directory("watch")
    defer { Scratch.remove(directory) }
    let watcher = DispatchDirectoryWatcher()
    await watcher.watch([directory])
    defer { watcher.stop() }

    let changed = changes(of: watcher)
    for i in 0..<20 {
      try "x".write(
        to: directory.appendingPathComponent("f\(i)"), atomically: true, encoding: .utf8)
    }

    try await waitUntil({ changed.received.count > 0 }, seconds: deliveryBound)
    #expect(changed.received.count > 0, "the burst arrived")
    try await Task.sleep(for: .seconds(1))
    #expect(changed.received.count == 1, "as one callback")
  }

  @Test func replacingTheWatchedSetStopsOldDirectoriesAndKeepsMissingOnesOut() async throws {
    let first = try Scratch.directory("watch")
    let second = try Scratch.directory("watch")
    defer {
      Scratch.remove(first)
      Scratch.remove(second)
    }
    let watcher = DispatchDirectoryWatcher()
    await watcher.watch([first, URL(fileURLWithPath: "/definitely/not/here")])
    await watcher.watch([second])
    defer { watcher.stop() }

    let firstChanges = changes(of: watcher)
    try "x".write(to: first.appendingPathComponent("ignored"), atomically: true, encoding: .utf8)
    try await waitUntil({ firstChanges.received.count > 0 }, seconds: 1)
    #expect(firstChanges.received.count == 0)

    let secondChanges = changes(of: watcher)
    try "x".write(to: second.appendingPathComponent("seen"), atomically: true, encoding: .utf8)
    try await waitUntil({ secondChanges.received.count > 0 }, seconds: deliveryBound)
    #expect(secondChanges.received.count > 0)
  }

  /// Every refresh re-arms the watcher and each source holds a descriptor until its
  /// cancel handler runs, so a leak there exhausts the process within a day of ticks.
  @Test func rearmingRepeatedlyDoesNotLeakDescriptors() async throws {
    let directories = try (0..<4).map { _ in try Scratch.directory("watch") }
    defer {
      for directory in directories { Scratch.remove(directory) }
    }
    let watcher = DispatchDirectoryWatcher()
    await watcher.watch(directories)

    for round in 0..<200 {
      // Alternate between the full set, a subset, and a set with a missing
      // directory, so sources are created, kept, cancelled and skipped.
      switch round % 3 {
      case 0: await watcher.watch(directories)
      case 1: await watcher.watch(Array(directories.prefix(2)))
      default: await watcher.watch([directories[3], URL(fileURLWithPath: "/definitely/not/here")])
      }
    }
    await watcher.watch(directories)

    let watched = Set(directories.compactMap { DispatchDirectoryWatcher.Identity(ofPath: $0.path) })
    try await waitUntil { descriptors(on: watched) == directories.count }
    #expect(descriptors(on: watched) == directories.count)
    watcher.stop()
  }

  /// Counted by what each descriptor names, as the process-wide count moves with
  /// whatever the suites beside this one have open.
  private func descriptors(on directories: Set<DispatchDirectoryWatcher.Identity>) -> Int {
    let open = (try? FileManager.default.contentsOfDirectory(atPath: "/dev/fd")) ?? []
    return open.compactMap(Int32.init).filter { descriptor in
      DispatchDirectoryWatcher.Identity(ofDescriptor: descriptor).map(directories.contains) ?? false
    }.count
  }

  @Test func directoriesAreOpenedOffTheMainThread() async throws {
    let directory = try Scratch.directory("watch")
    defer { Scratch.remove(directory) }
    let onMain = Recorder<String>()
    let watcher = DispatchDirectoryWatcher { path in
      onMain.record(Thread.isMainThread ? "main" : "off")
      return open(path, O_EVTONLY)
    }
    defer { watcher.stop() }

    await watcher.watch([directory])

    #expect(onMain.received == ["off"])
  }

  @Test func aWatchSupersededWhileItsDirectoriesOpenedArmsNothing() async throws {
    let superseded = try Scratch.directory("watch")
    let current = try Scratch.directory("watch")
    defer {
      Scratch.remove(superseded)
      Scratch.remove(current)
    }
    let opened = Recorder<String>()
    let gate = DispatchSemaphore(value: 0)
    let watcher = DispatchDirectoryWatcher { path in
      opened.record(path)
      if path == superseded.standardizedFileURL.path { gate.wait() }
      return open(path, O_EVTONLY)
    }
    defer { watcher.stop() }

    let supersededWatch = Task { await watcher.watch([superseded]) }
    try await waitUntil { !opened.received.isEmpty }
    await watcher.watch([current])
    gate.signal()
    await supersededWatch.value

    let supersededChanges = changes(of: watcher)
    try "x".write(
      to: superseded.appendingPathComponent("ignored"), atomically: true, encoding: .utf8)
    try await waitUntil({ supersededChanges.received.count > 0 }, seconds: 1)
    #expect(supersededChanges.received.count == 0)
  }

  @Test func stopSilencesTheWatcher() async throws {
    let directory = try Scratch.directory("watch")
    defer { Scratch.remove(directory) }
    let watcher = DispatchDirectoryWatcher()
    await watcher.watch([directory])
    watcher.stop()

    let changed = changes(of: watcher)
    try "x".write(
      to: directory.appendingPathComponent("after-stop"), atomically: true, encoding: .utf8)

    try await waitUntil({ changed.received.count > 0 }, seconds: 1)
    #expect(changed.received.count == 0)
  }
}

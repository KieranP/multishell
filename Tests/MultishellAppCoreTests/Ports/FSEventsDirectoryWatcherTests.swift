import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite(.serialized) @MainActor
struct FSEventsDirectoryWatcherTests {
  /// fseventsd and the busy main actor share a loaded runner, so this is far
  /// above the stream's latency.
  private let deliveryBound: Double = 30

  /// Call before the change: a batch with no listener is lost.
  private func changes(of watcher: FSEventsDirectoryWatcher) -> Recorder<[URL]> {
    let changes = Recorder<[URL]>()
    watcher.onChange = { changes.record($0) }
    return changes
  }

  /// Whether any change so far was `url` or lay under it.
  private func reported(_ url: URL, in changes: Recorder<[URL]>) -> Bool {
    changes.received.joined().contains { $0.pathComponents(under: url) != nil }
  }

  private func write(_ name: String, in directory: URL) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try "x".write(to: directory.appending(path: name), atomically: true, encoding: .utf8)
  }

  @Test func aFileWrittenDeepInAWatchedDirectoryReportsTheDirectoryHoldingIt() async throws {
    let directory = try Scratch.directory("watch")
    defer { Scratch.remove(directory) }
    try FileManager.default.createDirectory(
      at: directory.appending(path: "src/deep"),
      withIntermediateDirectories: true,
    )
    let watcher = FSEventsDirectoryWatcher()
    await watcher.watch([directory])
    defer { watcher.stop() }

    let changed = changes(of: watcher)
    try write("new.txt", in: directory.appending(path: "src/deep"))

    let deep = directory.appending(path: "src/deep")
    try await waitUntil({ reported(deep, in: changed) }, seconds: deliveryBound)
    #expect(
      changed.received.joined().contains { $0.standardizedFileURL == deep.standardizedFileURL }
    )
  }

  @Test func aFileWrittenDirectlyInAWatchedDirectoryReportsTheFile() async throws {
    let directory = try Scratch.directory("watch")
    defer { Scratch.remove(directory) }
    let watcher = FSEventsDirectoryWatcher()
    await watcher.watch([directory])
    defer { watcher.stop() }

    let changed = changes(of: watcher)
    try write("HEAD", in: directory)

    let head = directory.appending(path: "HEAD")
    try await waitUntil({ reported(head, in: changed) }, seconds: deliveryBound)
    #expect(reported(head, in: changed))
  }

  @Test func aDirectoryDeletedAndRemadeAtOnePathIsStillWatched() async throws {
    let parent = try Scratch.directory("watch")
    defer { Scratch.remove(parent) }
    let directory = parent.appending(path: "worktree", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let watcher = FSEventsDirectoryWatcher()
    await watcher.watch([directory])
    defer { watcher.stop() }

    try FileManager.default.removeItem(at: directory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let changed = changes(of: watcher)
    try write("seen", in: directory.appending(path: "src"))

    let src = directory.appending(path: "src")
    try await waitUntil({ reported(src, in: changed) }, seconds: deliveryBound)
    #expect(reported(src, in: changed))
  }

  @Test func replacingTheWatchedSetStopsOldDirectoriesAndKeepsMissingOnesOut() async throws {
    let first = try Scratch.directory("watch")
    let second = try Scratch.directory("watch")
    defer {
      Scratch.remove(first)
      Scratch.remove(second)
    }
    let watcher = FSEventsDirectoryWatcher()
    await watcher.watch([first])
    await watcher.watch([second, URL(fileURLWithPath: "/definitely/not/here")])
    defer { watcher.stop() }

    let changed = changes(of: watcher)
    try write("ignored", in: first)
    try write("seen", in: second)

    try await waitUntil({ reported(second, in: changed) }, seconds: deliveryBound)
    #expect(reported(second, in: changed))
    #expect(!reported(first, in: changed), "written first, so it would have come with it")
  }

  @Test func directoriesAreResolvedOffTheMainThread() async throws {
    let directory = try Scratch.directory("watch")
    defer { Scratch.remove(directory) }
    let onMain = Recorder<String>()
    let watcher = FSEventsDirectoryWatcher { directories in
      onMain.record(Thread.isMainThread ? "main" : "off")
      return WatchedDirectories(directories)
    }
    defer { watcher.stop() }

    await watcher.watch([directory])

    #expect(onMain.received == ["off"])
  }

  @Test func aWatchSupersededWhileItsDirectoriesResolvedArmsNothing() async throws {
    let superseded = try Scratch.directory("watch")
    let current = try Scratch.directory("watch")
    defer {
      Scratch.remove(superseded)
      Scratch.remove(current)
    }
    let asked = Recorder<URL>()
    let gate = DispatchSemaphore(value: 0)
    let watcher = FSEventsDirectoryWatcher { directories in
      asked.record(directories[0])
      if directories == [superseded] { gate.wait() }
      return WatchedDirectories(directories)
    }
    defer { watcher.stop() }

    let supersededWatch = Task { await watcher.watch([superseded]) }
    try await waitUntil { !asked.received.isEmpty }
    await watcher.watch([current])
    gate.signal()
    await supersededWatch.value

    let changed = changes(of: watcher)
    try write("ignored", in: superseded)
    try write("seen", in: current)
    try await waitUntil({ reported(current, in: changed) }, seconds: deliveryBound)
    #expect(reported(current, in: changed))
    #expect(!reported(superseded, in: changed))
  }

  /// The old stream sees the change and the new one starts after it, so only
  /// the old stream's batch carries it. A bystander watcher says it has landed.
  @Test func aChangeWhileTheWatchIsBeingReplacedIsReported() async throws {
    let directory = try Scratch.directory("watch")
    defer { Scratch.remove(directory) }
    let resolves = Recorder<Int>()
    let gate = DispatchSemaphore(value: 0)
    let watcher = FSEventsDirectoryWatcher { directories in
      resolves.record(0)
      if resolves.received.count == 2 { gate.wait() }
      return WatchedDirectories(directories)
    }
    defer { watcher.stop() }
    await watcher.watch([directory])
    let changed = changes(of: watcher)
    let bystander = FSEventsDirectoryWatcher()
    await bystander.watch([directory])
    defer { bystander.stop() }
    let seenByBystander = changes(of: bystander)

    let replacing = Task { await watcher.watch([directory]) }
    try await waitUntil { resolves.received.count == 2 }
    try write("during", in: directory)
    let during = directory.appending(path: "during")
    try await waitUntil({ reported(during, in: seenByBystander) }, seconds: deliveryBound)
    gate.signal()
    await replacing.value

    try await waitUntil({ reported(during, in: changed) }, seconds: 5)
    #expect(reported(during, in: changed))
  }

  @Test func stopSilencesTheWatcher() async throws {
    let directory = try Scratch.directory("watch")
    defer { Scratch.remove(directory) }
    let watcher = FSEventsDirectoryWatcher()
    await watcher.watch([directory])
    watcher.stop()
    let live = FSEventsDirectoryWatcher()
    await live.watch([directory])
    defer { live.stop() }

    let changed = changes(of: watcher)
    let liveChanges = changes(of: live)
    try write("after-stop", in: directory)

    try await waitUntil({ !liveChanges.received.isEmpty }, seconds: deliveryBound)
    #expect(!liveChanges.received.isEmpty)
    #expect(changed.received.isEmpty)
  }
}

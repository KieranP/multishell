import AppKit
import TestScratch
import Testing

@testable import MultishellAppUI

/// A promise on this process's own pasteboard is never asked for.
@Suite(.serialized) @MainActor
struct PromisedDropTests {
  /// Twenty seconds before giving up, which is a two-core runner's headroom
  /// over a handful of operations.
  private func awaitDelivery(_ delivery: Recorder<[URL]>) async throws -> [URL] {
    try await waitUntil({ !delivery.received.isEmpty }, seconds: 20)
    return try #require(delivery.received.first, "the drop was never delivered")
  }

  @Test func anItemNamingTwoFilesOnceCalledInDeliversBoth() async throws {
    let delivery = Recorder<[URL]>()
    let directory = Scratch.path("promised")
    defer { Scratch.remove(directory) }

    PromisedDrop.receive([TwoFilePromise()], into: directory) { delivery.record($0) }

    #expect(try await awaitDelivery(delivery).map(\.lastPathComponent) == ["one.png", "two.png"])
  }

  @Test func anItemsFilesLandingOutOfOrderArePastedInTheOrderItNamesThem() async throws {
    let delivery = Recorder<[URL]>()
    let directory = Scratch.path("promised")
    defer { Scratch.remove(directory) }

    let promise = TwoFilePromise(landing: ["two.png", "one.png"])
    PromisedDrop.receive([promise], into: directory) { delivery.record($0) }

    #expect(try await awaitDelivery(delivery).map(\.lastPathComponent) == ["one.png", "two.png"])
  }

  @Test func aDragWithNoPromisesIsAnsweredAtOnce() {
    let delivery = Recorder<[URL]>()
    // Its own directory, since `receive` deletes what it was given when nothing arrives.
    let directory = Scratch.path("promised")
    PromisedDrop.receive([], into: directory) { delivery.record($0) }
    #expect(delivery.received == [[]])
  }

  /// Nowhere to put the files is the same answer as no files, not a silence:
  /// the state directory can refuse, and the drag still has to be told.
  @Test func aDropWithNowhereToReceiveIntoDeliversNothing() {
    let delivery = Recorder<[URL]>()
    PromisedDrop.receive([], into: nil) { delivery.record($0) }
    #expect(delivery.received == [[]])
  }

  /// The directory exists before the sources are asked, and an empty one would otherwise
  /// sit in the state directory until the sweep a week later.
  @Test func aDropThatDeliversNothingTakesItsDirectoryBack() throws {
    let directory = try Scratch.directory("promised")
    defer { Scratch.remove(directory) }

    PromisedDrop.receive([], into: directory) { _ in }

    #expect(!FileManager.default.fileExists(atPath: directory.path))
  }

  @Test func aDropAnsweredAtOnceIsNotAnsweredAgainWhenThePatienceRunsOut() async throws {
    let delivery = Recorder<[URL]>()
    let directory = Scratch.path("promised")

    PromisedDrop.receive([], into: directory, givingUpAfter: 0.05) { delivery.record($0) }
    #expect(delivery.received.count == 1)
    try await Task.sleep(for: .milliseconds(300))

    #expect(delivery.received.count == 1)
  }
}

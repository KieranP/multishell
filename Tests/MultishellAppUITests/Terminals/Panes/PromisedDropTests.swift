import AppKit
import Testing

@testable import MultishellAppUI

/// A promise on this process's own pasteboard is never asked for.
@Suite(.serialized) @MainActor
struct PromisedDropTests {
  /// Holds what came back, since delivery lands after the call returns, and
  /// counts the answers: the drop is pasted once or it is pasted twice.
  @MainActor private final class Delivery {
    var urls: [URL]?
    var answers = 0

    func answer(_ urls: [URL]) {
      self.urls = urls
      answers += 1
    }
  }

  /// Twenty seconds before giving up, which is a two-core runner's headroom
  /// over a handful of operations.
  private func awaitDelivery(_ delivery: Delivery) async throws -> [URL] {
    for _ in 0..<400 where delivery.urls == nil {
      try await Task.sleep(for: .milliseconds(50))
    }
    return try #require(delivery.urls, "the drop was never delivered")
  }

  /// A legacy source, whose one item names several files. AppKit's `fileNames`
  /// is empty until the promise is called in, per NSFilePromiseReceiver.h.
  private final class TwoFilePromise: NSFilePromiseReceiver {
    private var calledIn = false
    private var landing: [String] = ["one.png", "two.png"]

    convenience init(landing: [String]) {
      self.init()
      self.landing = landing
    }

    override var fileNames: [String] { calledIn ? ["one.png", "two.png"] : [] }

    override func receivePromisedFiles(
      atDestination destination: URL, options: [AnyHashable: Any] = [:],
      operationQueue: OperationQueue,
      reader: @escaping (URL, (any Error)?) -> Void
    ) {
      calledIn = true
      // AppKit's own signature is not `@Sendable`, though it calls the reader off the main actor.
      nonisolated(unsafe) let reader = reader
      let urls = landing.map { destination.appendingPathComponent($0) }
      operationQueue.addOperation { for url in urls { reader(url, nil) } }
    }
  }

  @Test func anItemNamingTwoFilesOnceCalledInDeliversBoth() async throws {
    let delivery = Delivery()
    let directory = ScratchDirectory.path("promised")
    defer { ScratchDirectory.remove(directory) }

    PromisedDrop.receive([TwoFilePromise()], into: directory) { delivery.answer($0) }

    #expect(try await awaitDelivery(delivery).map(\.lastPathComponent) == ["one.png", "two.png"])
  }

  @Test func anItemsFilesLandingOutOfOrderArePastedInTheOrderItNamesThem() async throws {
    let delivery = Delivery()
    let directory = ScratchDirectory.path("promised")
    defer { ScratchDirectory.remove(directory) }

    let promise = TwoFilePromise(landing: ["two.png", "one.png"])
    PromisedDrop.receive([promise], into: directory) { delivery.answer($0) }

    #expect(try await awaitDelivery(delivery).map(\.lastPathComponent) == ["one.png", "two.png"])
  }

  @Test func aDragWithNoPromisesIsAnsweredAtOnce() {
    let delivery = Delivery()
    // Its own directory, since `receive` deletes what it was given when nothing arrives.
    let directory = ScratchDirectory.path("promised")
    PromisedDrop.receive([], into: directory) { delivery.answer($0) }
    #expect(delivery.urls == [])
  }

  /// Nowhere to put the files is the same answer as no files, not a silence:
  /// the state directory can refuse, and the drag still has to be told.
  @Test func aDropWithNowhereToReceiveIntoDeliversNothing() {
    let delivery = Delivery()
    PromisedDrop.receive([], into: nil) { delivery.answer($0) }
    #expect(delivery.urls == [])
  }

  /// The directory exists before the sources are asked, and an empty one would otherwise
  /// sit in the state directory until the sweep a week later.
  @Test func aDropThatDeliversNothingTakesItsDirectoryBack() throws {
    let directory = try ScratchDirectory.make("promised")
    defer { ScratchDirectory.remove(directory) }

    PromisedDrop.receive([], into: directory) { _ in }

    #expect(!FileManager.default.fileExists(atPath: directory.path))
  }

  @Test func aDropAnsweredAtOnceIsNotAnsweredAgainWhenThePatienceRunsOut() async throws {
    let delivery = Delivery()
    let directory = ScratchDirectory.path("promised")

    PromisedDrop.receive([], into: directory, givingUpAfter: 0.05) { delivery.answer($0) }
    #expect(delivery.answers == 1)
    try await Task.sleep(for: .milliseconds(300))

    #expect(delivery.answers == 1)
  }

  /// Registering none of them would leave a promise-only drag with no drop
  /// offered at all, which is what a screenshot's preview is.
  @Test func thePromiseTypesAreRegisteredForOrNoSuchDragIsOffered() {
    #expect(!PromisedDrop.draggedTypes.isEmpty)
  }
}

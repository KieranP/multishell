import Foundation
import Testing

@testable import MultishellAppCore

/// AppKit calls the reader off the main actor, and one assuming the main actor traps on
/// every promised drop.
@Suite(.serialized) @MainActor
struct PromisedDropCollectorTests {
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

  private func file(_ name: String) -> URL {
    URL(fileURLWithPath: "/drops/\(UUID().uuidString)/\(name)")
  }

  /// Reports files the way AppKit does: off the main actor, one operation
  /// each, in whatever order the queue runs them.
  private func report(_ files: [(index: Int, url: URL?)], to collector: PromisedDropCollector) {
    let queue = OperationQueue()
    let readers = files.map { PromisedDropCollector.reader(reporting: $0.index, to: collector) }
    for (reader, file) in zip(readers, files) {
      queue.addOperation {
        #expect(!Thread.isMainThread, "AppKit reports a promised file from its own queue")
        reader(
          file.url ?? URL(fileURLWithPath: "/nothing"),
          file.url == nil ? CocoaError(.fileWriteUnknown) : nil)
      }
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

  @Test func aFileReportedOffTheMainActorIsDelivered() async throws {
    let delivery = Delivery()
    let collector = PromisedDropCollector(expecting: [1]) { delivery.answer($0) }
    let shot = file("Screenshot.png")

    report([(0, shot)], to: collector)

    #expect(try await awaitDelivery(delivery) == [shot])
  }

  @Test func theFilesArriveInTheDragsOrderWhateverOrderTheyLandIn() async throws {
    let delivery = Delivery()
    let files = (0..<8).map { file("shot-\($0).png") }
    let collector = PromisedDropCollector(expecting: files.map { _ in 1 }) { delivery.answer($0) }

    report(files.enumerated().map { (index: $0.offset, url: $0.element) }.shuffled(), to: collector)

    #expect(try await awaitDelivery(delivery) == files)
  }

  @Test func aFileTheSourceRefusesIsLeftOutAndTheRestArrive() async throws {
    let delivery = Delivery()
    let written = file("written.png")
    let collector = PromisedDropCollector(expecting: [1, 1]) { delivery.answer($0) }

    report([(0, nil), (1, written)], to: collector)

    #expect(try await awaitDelivery(delivery) == [written])
  }

  /// Nothing arriving is still an answer: the caller pastes nothing for it,
  /// where never answering would leave the drag unanswered.
  @Test func aDragWhoseFilesAllFailDeliversNothing() async throws {
    let delivery = Delivery()
    let collector = PromisedDropCollector(expecting: [1, 1]) { delivery.answer($0) }

    report([(0, nil), (1, nil)], to: collector)

    #expect(try await awaitDelivery(delivery).isEmpty)
  }

  /// A source reporting twice breaks its own promise, but the extra file is still kept.
  @Test func aSecondReportFromOneSourceDoesNotDeliverTheDropEarly() async throws {
    let delivery = Delivery()
    let first = file("first.png")
    let second = file("second.png")
    let late = file("late.png")
    let collector = PromisedDropCollector(expecting: [1, 1]) { delivery.answer($0) }

    collector.received(first, from: 0)
    collector.received(second, from: 0)
    #expect(delivery.urls == nil, "the second source has not reported yet")
    collector.received(late, from: 1)

    #expect(try await awaitDelivery(delivery) == [first, second, late])
  }

  /// AppKit calls the reader once per promised name, so counting items delivered on the
  /// first and left the rest in the drop directory, never pasted.
  @Test func anItemPromisingTwoFilesIsNotDeliveredOnTheFirst() async throws {
    let delivery = Delivery()
    let first = file("one.png")
    let second = file("two.png")
    let other = file("other.png")
    let collector = PromisedDropCollector(expecting: [2, 1]) { delivery.answer($0) }

    collector.received(first, from: 0)
    collector.received(other, from: 1)
    #expect(delivery.urls == nil, "the first item has another file coming")
    collector.received(second, from: 0)

    #expect(try await awaitDelivery(delivery) == [first, second, other])
  }

  /// A source is not obliged to answer, and one that never does would hold the drop, with
  /// no paste and no refusal, for as long as the app runs.
  @Test func aSourceThatNeverAnswersDoesNotHoldTheDropForGood() {
    let delivery = Delivery()
    let arrived = file("arrived.png")
    let collector = PromisedDropCollector(expecting: [1, 1]) { delivery.answer($0) }

    collector.received(arrived, from: 0)
    #expect(delivery.urls == nil, "the second source has not answered")
    collector.giveUp()

    #expect(delivery.urls == [arrived], "what arrived is still worth pasting")
  }

  @Test func aSourceReportingAfterTheDropWasGivenUpOnPastesNothingMore() async throws {
    let delivery = Delivery()
    let collector = PromisedDropCollector(expecting: [1, 1]) { delivery.answer($0) }

    collector.giveUp()
    #expect(delivery.answers == 1)

    report([(0, file("late.png")), (1, file("later.png"))], to: collector)
    try await Task.sleep(for: .milliseconds(200))
    #expect(delivery.answers == 1, "the drop was answered when it was given up on")
    #expect(delivery.urls == [])
  }
}

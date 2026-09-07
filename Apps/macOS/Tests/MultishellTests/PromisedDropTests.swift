import AppKit
import Testing

@testable import Multishell

/// Files a drag promises rather than hands over: a screenshot's preview is
/// the one that matters, and its copy has to arrive somewhere the pane can
/// read before a path is worth pasting.
///
/// The receipt is what these exercise, from the reader AppKit calls as each
/// file lands. That reader runs on the queue it was given, never the main
/// actor, and a reader written as if it did runs into an isolation check the
/// moment a file arrives: the app dies on every promised drop, and nothing
/// but a real drag shows it. So every test here calls the reader off the main
/// actor, the way AppKit does.
///
/// The drag itself cannot be staged: a promise is fulfilled through a drag
/// session, and one written to a pasteboard in this process is never asked
/// for. What can be had without one is everything from the reader inwards,
/// which is where the crash was and where the ordering lives.
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

  private func file(_ name: String) -> URL {
    URL(fileURLWithPath: "/drops/\(UUID().uuidString)/\(name)")
  }

  /// Reports files the way AppKit does: off the main actor, one operation
  /// each, in whatever order the queue runs them.
  private func report(_ files: [(index: Int, url: URL?)], to collector: PromisedDrop.Collector) {
    let queue = OperationQueue()
    let readers = files.map { PromisedDrop.reader(reporting: $0.index, to: collector) }
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

  /// The one that would have caught the crash: a file reported from an
  /// operation queue has to reach the main actor rather than trap on the way.
  @Test func aFileReportedOffTheMainActorIsDelivered() async throws {
    let delivery = Delivery()
    let collector = PromisedDrop.Collector(expecting: 1) { delivery.answer($0) }
    let shot = file("Screenshot.png")

    report([(0, shot)], to: collector)

    #expect(try await awaitDelivery(delivery) == [shot])
  }

  /// Several files land in whatever order their sources write them, and the
  /// prompt reads them in the order they were dragged.
  @Test func theFilesArriveInTheDragsOrderWhateverOrderTheyLandIn() async throws {
    let delivery = Delivery()
    let files = (0..<8).map { file("shot-\($0).png") }
    let collector = PromisedDrop.Collector(expecting: files.count) { delivery.answer($0) }

    report(files.enumerated().map { (index: $0.offset, url: $0.element) }.shuffled(), to: collector)

    #expect(try await awaitDelivery(delivery) == files)
  }

  /// A source that will not write its file costs that file and no more: the
  /// rest of the drag is still worth pasting.
  @Test func aFileTheSourceRefusesIsLeftOutAndTheRestArrive() async throws {
    let delivery = Delivery()
    let written = file("written.png")
    let collector = PromisedDrop.Collector(expecting: 2) { delivery.answer($0) }

    report([(0, nil), (1, written)], to: collector)

    #expect(try await awaitDelivery(delivery) == [written])
  }

  /// Nothing arriving is still an answer: the caller pastes nothing for it,
  /// where never answering would leave the drag unanswered.
  @Test func aDragWhoseFilesAllFailDeliversNothing() async throws {
    let delivery = Delivery()
    let collector = PromisedDrop.Collector(expecting: 2) { delivery.answer($0) }

    report([(0, nil), (1, nil)], to: collector)

    #expect(try await awaitDelivery(delivery).isEmpty)
  }

  /// A source reporting twice is one breaking its own promise. The extra file
  /// is kept, but it must not count again: counting it would deliver the drop
  /// while another file was still coming.
  @Test func aSecondReportFromOneSourceDoesNotDeliverTheDropEarly() async throws {
    let delivery = Delivery()
    let first = file("first.png")
    let second = file("second.png")
    let late = file("late.png")
    let collector = PromisedDrop.Collector(expecting: 2) { delivery.answer($0) }

    collector.received(first, from: 0)
    collector.received(second, from: 0)
    #expect(delivery.urls == nil, "the second source has not reported yet")
    collector.received(late, from: 1)

    #expect(try await awaitDelivery(delivery) == [first, second, late])
  }

  /// A drag carrying no promise at all is answered at once rather than left,
  /// since the caller is waiting on that answer.
  @Test func aDragWithNoPromisesIsAnsweredAtOnce() {
    let delivery = Delivery()
    // A directory of this test's own: `receive` takes back what it was given
    // when nothing arrives, and a real path here would be a test that deletes
    // it.
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("ms-promised-\(UUID().uuidString)", isDirectory: true)
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

  /// A drag none of whose files arrive leaves nothing behind. The directory
  /// is made before the sources are asked, and an empty one would otherwise
  /// sit in the state directory until the sweep a week later.
  @Test func aDropThatDeliversNothingTakesItsDirectoryBack() throws {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("ms-promised-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    PromisedDrop.receive([], into: directory) { _ in }

    #expect(!FileManager.default.fileExists(atPath: directory.path))
  }

  /// A source is not obliged to answer. One that never does would otherwise
  /// hold the drop for as long as the app runs — no paste, no refusal — so
  /// the drop is given up on and what did arrive is delivered.
  @Test func aSourceThatNeverAnswersDoesNotHoldTheDropForGood() {
    let delivery = Delivery()
    let arrived = file("arrived.png")
    let collector = PromisedDrop.Collector(expecting: 2) { delivery.answer($0) }

    collector.received(arrived, from: 0)
    #expect(delivery.urls == nil, "the second source has not answered")
    collector.giveUp()

    #expect(delivery.urls == [arrived], "what arrived is still worth pasting")
  }

  /// The one answer is the whole of it: a source reporting after the drop was
  /// given up on must not paste a second time.
  @Test func aSourceReportingAfterTheDropWasGivenUpOnPastesNothingMore() async throws {
    let delivery = Delivery()
    let collector = PromisedDrop.Collector(expecting: 2) { delivery.answer($0) }

    collector.giveUp()
    #expect(delivery.answers == 1)

    report([(0, file("late.png")), (1, file("later.png"))], to: collector)
    try await Task.sleep(for: .milliseconds(200))
    #expect(delivery.answers == 1, "the drop was answered when it was given up on")
    #expect(delivery.urls == [])
  }

  /// The timer behind a drop is dropped with it: a drag that answered at once
  /// must not be answered again when the patience runs out.
  @Test func aDropAnsweredAtOnceIsNotAnsweredAgainWhenThePatienceRunsOut() async throws {
    let delivery = Delivery()
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("ms-promised-\(UUID().uuidString)", isDirectory: true)

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

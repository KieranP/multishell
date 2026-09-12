import AppKit
import MultishellAppCore

/// Files a drag promises rather than hands over: a screenshot preview's own
/// copy is `EPERM` to the pane's shell, and the promise is the way round.
@MainActor
enum PromisedDrop {
  /// The types a promise arrives under, which the frame registers alongside
  /// `.fileURL` so a drag with nothing but a promise is offered a drop too.
  static var draggedTypes: [NSPasteboard.PasteboardType] {
    NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) }
  }

  static func receivers(from sender: any NSDraggingInfo) -> [NSFilePromiseReceiver] {
    sender.draggingPasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self])
      as? [NSFilePromiseReceiver] ?? []
  }

  /// How long a source is given before the drop is answered without it: room
  /// for a large file, and a bound on one that never answers.
  static let patience: TimeInterval = 120

  /// Takes the copies, then hands over what arrived. What the source failed
  /// to write is left out, so the rest of a drag still delivers.
  static func receive(
    _ receivers: [NSFilePromiseReceiver],
    into destination: URL? = try? DroppedFiles.makeDirectory(),
    givingUpAfter patience: TimeInterval = patience,
    then deliver: @escaping ([URL]) -> Void
  ) {
    guard let directory = destination else { return deliver([]) }
    // The directory is made before the sources are asked, so one nothing
    // arrives in would linger until the sweep. It is this drag's own.
    let collector = Collector(expecting: receivers.count) { urls in
      if urls.isEmpty { try? FileManager.default.removeItem(at: directory) }
      deliver(urls)
    }
    let queue = OperationQueue()
    collector.queue = queue
    for (index, receiver) in receivers.enumerated() {
      receiver.receivePromisedFiles(
        atDestination: directory, options: [:], operationQueue: queue,
        reader: reader(reporting: index, to: collector))
    }
    // Nothing obliges a source to answer, and one that does not would hold
    // the drop for as long as the app runs. What arrived is delivered.
    guard !collector.isDelivered else { return }
    collector.giveUpTimer = Task { @MainActor in
      try? await Task.sleep(for: .seconds(patience))
      guard !Task.isCancelled else { return }
      collector.giveUp()
    }
  }

  /// What AppKit calls as each file lands, off the main actor. A `@Sendable`
  /// type on purpose: an inline closure would inherit isolation and trap.
  static func reader(
    reporting index: Int, to collector: Collector
  ) -> @Sendable (URL, (any Error)?) -> Void {
    { url, error in
      let received = error == nil ? url : nil
      Task { @MainActor in collector.received(received, from: index) }
    }
  }

  /// Keeps the drag's order while files land in whatever order sources write
  /// them. A second report for one item is kept but does not count again.
  @MainActor
  final class Collector {
    private var files: [[URL]]
    private var waiting: Set<Int>
    private let deliver: ([URL]) -> Void
    private var delivered = false

    /// Cancelled the moment the drop is answered, so a drag that finished
    /// does not keep a timer running behind it.
    var giveUpTimer: Task<Void, Never>?

    /// Held, because `receivePromisedFiles` is not documented to keep the
    /// queue it is handed and a released one never calls the reader.
    var queue: OperationQueue?

    var isDelivered: Bool { delivered }

    init(expecting count: Int, deliver: @escaping ([URL]) -> Void) {
      files = Array(repeating: [], count: count)
      waiting = Set(0..<count)
      self.deliver = deliver
      if count == 0 { answer() }
    }

    func received(_ url: URL?, from index: Int) {
      if let url { files[index].append(url) }
      guard waiting.remove(index) != nil, waiting.isEmpty else { return }
      answer()
    }

    /// What arrived, when the rest never will.
    func giveUp() { answer() }

    /// The drop is answered once. A source reporting after the drop was given
    /// up on, or twice, must not paste a second time.
    private func answer() {
      guard !delivered else { return }
      delivered = true
      giveUpTimer?.cancel()
      deliver(files.flatMap { $0 })
    }
  }
}

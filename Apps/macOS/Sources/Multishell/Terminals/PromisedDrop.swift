import AppKit
import MultishellAppCore

/// Files a drag promises rather than hands over.
///
/// A screenshot's floating preview is the one every user meets. Its
/// pasteboard does carry a file URL, so a drop looks like an ordinary one,
/// but that copy sits under `TemporaryItems` in a directory macOS opens to
/// the receiving app alone: the app can read it and the shell in the pane,
/// and the agent at its prompt, are refused it — `EPERM`, on a path that is
/// there. Pasting it leaves a file name nothing at that prompt can open.
///
/// The promise is the way to a copy the pane can read. Received into a
/// directory of ours, the file arrives as an ordinary one, and that is the
/// path the terminal is told.
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

  /// How long a source is given before the drop is answered without it. A
  /// large file off a slow disk has room in it, and a source that will never
  /// answer does not hold the drop for good.
  static let patience: TimeInterval = 120

  /// Takes the copies, then hands over what arrived. Files the source fails
  /// to write are left out, so a drag half of whose files failed still
  /// delivers the rest; nothing arriving at all delivers an empty array,
  /// which the caller pastes nothing for.
  static func receive(
    _ receivers: [NSFilePromiseReceiver],
    into destination: URL? = try? DroppedFiles.makeDirectory(),
    givingUpAfter patience: TimeInterval = patience,
    then deliver: @escaping ([URL]) -> Void
  ) {
    guard let directory = destination else { return deliver([]) }
    // The directory is made before the sources are asked, so a drag none of
    // whose files arrive would leave an empty one behind until the sweep a
    // week later. It is this drag's own, so taking it back is safe.
    let collector = Collector(expecting: receivers.count) { urls in
      if urls.isEmpty { try? FileManager.default.removeItem(at: directory) }
      deliver(urls)
    }
    let queue = OperationQueue()
    for (index, receiver) in receivers.enumerated() {
      receiver.receivePromisedFiles(
        atDestination: directory, options: [:], operationQueue: queue,
        reader: reader(reporting: index, to: collector))
    }
    // Nothing obliges a source to answer, and one that does not would leave
    // the drop waiting for as long as the app runs: no paste, no refusal,
    // and the drag long gone. What arrived by then is delivered instead.
    guard !collector.isDelivered else { return }
    collector.giveUpTimer = Task { @MainActor in
      try? await Task.sleep(for: .seconds(patience))
      guard !Task.isCancelled else { return }
      collector.giveUp()
    }
  }

  /// What AppKit calls as each file lands, on the queue it was given rather
  /// than on the main actor.
  ///
  /// Written as a value of a `@Sendable` type on purpose. A closure written
  /// inline here would take the main actor's isolation from the method around
  /// it and trap the moment a file arrived — a crash on every promised drop,
  /// which no build and no drag-free test would show. Spelling the type out
  /// puts that where the compiler will not allow it: an isolated closure does
  /// not convert to this.
  static func reader(
    reporting index: Int, to collector: Collector
  ) -> @Sendable (URL, (any Error)?) -> Void {
    { url, error in
      let received = error == nil ? url : nil
      Task { @MainActor in collector.received(received, from: index) }
    }
  }

  /// Keeps the drag's order while the files land in whatever order the
  /// sources write them.
  ///
  /// One pasteboard item promises one file, so a receiver reporting twice
  /// would be a source breaking that; the second report is kept but does not
  /// count again, which is what would deliver a drop early.
  @MainActor
  final class Collector {
    private var files: [[URL]]
    private var waiting: Set<Int>
    private let deliver: ([URL]) -> Void
    private var delivered = false

    /// Cancelled the moment the drop is answered, so a drag that finished
    /// does not keep a timer running behind it.
    var giveUpTimer: Task<Void, Never>?

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

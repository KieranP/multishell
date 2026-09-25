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
  static let defaultPatience: TimeInterval = 120

  /// Takes the copies, then hands over what arrived. What the source failed
  /// to write is left out, so the rest of a drag still delivers.
  static func receive(
    _ receivers: [NSFilePromiseReceiver],
    into destination: URL? = try? PromisedDropCopies.makeDirectory(),
    givingUpAfter patience: TimeInterval = defaultPatience,
    then deliver: @escaping ([URL]) -> Void
  ) {
    guard let directory = destination else { return deliver([]) }
    // `fileNames` is empty until a promise is called in, so it is read per report.
    let promised = { (index: Int) in max(1, receivers[index].fileNames.count) }
    // The directory is made before the sources are asked, so one nothing
    // arrives in would linger until the sweep. It is this drag's own.
    let collector = PromisedDropCollector(
      expecting: receivers.map { _ in 1 }, recounting: promised,
      naming: { receivers[$0].fileNames },
      deliver: { urls in
        if urls.isEmpty { try? FileManager.default.removeItem(at: directory) }
        deliver(urls)
      })
    let queue = OperationQueue()
    collector.queue = queue
    for (index, receiver) in receivers.enumerated() {
      receiver.receivePromisedFiles(
        atDestination: directory, options: [:], operationQueue: queue,
        reader: PromisedDropCollector.reader(reporting: index, to: collector))
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
}

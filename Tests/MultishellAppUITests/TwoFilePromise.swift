import AppKit

/// A legacy source, whose one item names several files. AppKit's `fileNames`
/// is empty until the promise is called in, per NSFilePromiseReceiver.h.
final class TwoFilePromise: NSFilePromiseReceiver {
  private var isCalledIn = false
  private var landing: [String] = ["one.png", "two.png"]

  override var fileNames: [String] { isCalledIn ? ["one.png", "two.png"] : [] }

  convenience init(landing: [String]) {
    self.init()
    self.landing = landing
  }

  override func receivePromisedFiles(
    atDestination destination: URL,
    options: [AnyHashable: Any] = [:],
    operationQueue: OperationQueue,
    reader: @escaping (URL, (any Error)?) -> Void,
  ) {
    isCalledIn = true
    // AppKit's own signature is not `@Sendable`, though it calls the reader off the main actor.
    nonisolated(unsafe) let reader = reader
    let urls = landing.map { destination.appendingPathComponent($0) }
    operationQueue.addOperation { for url in urls { reader(url, nil) } }
  }
}

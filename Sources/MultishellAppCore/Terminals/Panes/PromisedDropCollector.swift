import Foundation

/// Keeps a promised drop's order while files land in any order. An item
/// retires once its own are in; a report past that is kept but does not count.
@MainActor
public final class PromisedDropCollector {
  private var files: [[URL]]
  private var reported: [Int]
  private var promisedCount: (Int) -> Int
  private var fileNamesOfItem: ((Int) -> [String])?
  private var waiting: Set<Int>
  private let onDelivery: ([URL]) -> Void

  /// Cancelled the moment the drop is delivered, so a drag that finished
  /// does not keep a timer running behind it.
  public var giveUpTimer: Task<Void, Never>?

  /// Held, because `receivePromisedFiles` is not documented to keep the
  /// queue it is handed and a released one never calls the reader.
  public var readerQueue: OperationQueue?

  public private(set) var isDelivered = false

  /// `counts` per item in the drag's order; `recounting` replaces one once a
  /// report knows it, and `fileNamesOfItem` orders an item's own files.
  public init(
    expecting counts: [Int], recounting: ((Int) -> Int)? = nil,
    fileNamesOfItem: ((Int) -> [String])? = nil, onDelivery: @escaping ([URL]) -> Void
  ) {
    files = Array(repeating: [], count: counts.count)
    reported = Array(repeating: 0, count: counts.count)
    promisedCount = recounting ?? { counts[$0] }
    self.fileNamesOfItem = fileNamesOfItem
    waiting = Set(counts.indices.filter { counts[$0] > 0 })
    self.onDelivery = onDelivery
    if waiting.isEmpty { deliver() }
  }

  /// What AppKit calls as each file lands, off the main actor. A `@Sendable`
  /// type on purpose: an inline closure would inherit isolation and trap.
  public static func reader(
    reporting index: Int, to collector: PromisedDropCollector
  ) -> @Sendable (URL, (any Error)?) -> Void {
    { url, error in
      let received = error == nil ? url : nil
      Task { @MainActor in collector.received(received, from: index) }
    }
  }

  func received(_ url: URL?, from index: Int) {
    if let url { files[index].append(url) }
    reported[index] += 1
    guard reported[index] >= promisedCount(index) else { return }
    guard waiting.remove(index) != nil, waiting.isEmpty else { return }
    deliver()
  }

  /// What arrived, when the rest never will.
  public func giveUp() { deliver() }

  /// The drop is delivered once. A source reporting after the drop was given
  /// up on, or twice, must not paste a second time.
  private func deliver() {
    guard !isDelivered else { return }
    isDelivered = true
    giveUpTimer?.cancel()
    // The queue holds the reader, which holds this, so a source that never
    // writes would leave all three standing; `promisedCount` holds the receivers.
    readerQueue = nil
    let ordered = files.indices.map {
      Self.inNamedOrder(files[$0], names: fileNamesOfItem?($0) ?? [])
    }
    promisedCount = { _ in 1 }
    fileNamesOfItem = nil
    onDelivery(ordered.flatMap { $0 })
  }

  /// One item's files land in whatever order its queue runs them. A name the
  /// item did not give goes last, in the order it landed.
  private static func inNamedOrder(_ urls: [URL], names: [String]) -> [URL] {
    let rank = Dictionary(
      keepingFirst:
        names.enumerated().map { ($1, $0) })
    let key = { (offset: Int, url: URL) in (rank[url.lastPathComponent] ?? names.count, offset) }
    return urls.enumerated().sorted { key($0.offset, $0.element) < key($1.offset, $1.element) }
      .map(\.element)
  }
}

import Foundation

/// Keeps a promised drop's order while files land in any order. An item
/// retires once its own are in; a report past that is kept but does not count.
@MainActor
public final class PromisedDropCollector {
  private var files: [[URL]]
  private var reported: [Int]
  private var promised: (Int) -> Int
  private var waiting: Set<Int>
  private let deliver: ([URL]) -> Void
  private var delivered = false

  /// Cancelled the moment the drop is answered, so a drag that finished
  /// does not keep a timer running behind it.
  public var giveUpTimer: Task<Void, Never>?

  /// Held, because `receivePromisedFiles` is not documented to keep the
  /// queue it is handed and a released one never calls the reader.
  public var queue: OperationQueue?

  public var isDelivered: Bool { delivered }

  /// `counts` is how many files each item promised, in the drag's order;
  /// `recounting` replaces an item's count once a report says it is known.
  public init(
    expecting counts: [Int], recounting: ((Int) -> Int)? = nil,
    deliver: @escaping ([URL]) -> Void
  ) {
    files = Array(repeating: [], count: counts.count)
    reported = Array(repeating: 0, count: counts.count)
    promised = recounting ?? { counts[$0] }
    waiting = Set(counts.indices.filter { counts[$0] > 0 })
    self.deliver = deliver
    if waiting.isEmpty { answer() }
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
    guard reported[index] >= promised(index) else { return }
    guard waiting.remove(index) != nil, waiting.isEmpty else { return }
    answer()
  }

  /// What arrived, when the rest never will.
  public func giveUp() { answer() }

  /// The drop is answered once. A source reporting after the drop was given
  /// up on, or twice, must not paste a second time.
  private func answer() {
    guard !delivered else { return }
    delivered = true
    giveUpTimer?.cancel()
    // The queue holds the reader, which holds this, so a source that never
    // writes would leave all three standing; `promised` holds the receivers.
    queue = nil
    promised = { _ in 1 }
    deliver(files.flatMap { $0 })
  }
}

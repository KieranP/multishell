import Foundation

/// Writes to one file in order and one at a time, whichever thread runs each;
/// see Docs/design/state-and-store.md.
public final class SaveOrder: @unchecked Sendable {
  /// A place in the order, taken where the value to write is read. A write
  /// whose ticket is older than the last landed is dropped, not written.
  public struct Ticket: Sendable {
    fileprivate let number: Int
  }

  private let lock = NSLock()
  private var issued = 0
  private var landed = 0

  public init() {}

  public func issue() -> Ticket {
    lock.withLock {
      issued += 1
      return Ticket(number: issued)
    }
  }

  /// What `write` returned, or `nil` where a later ticket landed first.
  @discardableResult
  public func land<Value>(_ ticket: Ticket, _ write: () throws -> Value) rethrows -> Value? {
    try lock.withLock {
      guard ticket.number > landed else { return nil }
      let value = try write()
      landed = ticket.number
      return value
    }
  }

  /// Whether the file still holds what this ticket wrote, nothing later
  /// having landed over it.
  public func isLastLanded(_ ticket: Ticket) -> Bool {
    lock.withLock { landed == ticket.number }
  }
}

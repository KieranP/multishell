import Foundation
import Synchronization

/// Writes to one file in order and one at a time, whichever thread runs each;
/// see Docs/design/state-and-store.md.
public final class SaveOrder: Sendable {
  /// A place in the order, taken where the value to write is read. A write
  /// whose ticket is older than the last landed is dropped, not written.
  public struct Ticket: Sendable {
    fileprivate let number: Int
  }

  /// Apart from `writing`, which a write holds for its whole length: `issue`
  /// runs on the main actor, and a stalled volume would hold the window.
  private let issued = Atomic(0)
  private let landing = Atomic(0)
  private let landed = Atomic(0)
  private let writing = Mutex(())

  public init() {}

  public func issue() -> Ticket {
    Ticket(number: issued.add(1, ordering: .relaxed).newValue)
  }

  /// What `write` returned, or `nil` where a later ticket landed first.
  @discardableResult
  public func land<Value>(_ ticket: Ticket, _ write: () throws -> Value) rethrows -> Value? {
    try writing.withLock { _ in
      let last = landed.load(ordering: .acquiring)
      guard ticket.number > last else { return nil }
      landing.store(ticket.number, ordering: .releasing)
      do {
        let value = try write()
        landed.store(ticket.number, ordering: .releasing)
        return value
      } catch {
        landing.store(last, ordering: .releasing)
        throw error
      }
    }
  }

  /// Whether the file still holds what this ticket wrote, nothing later
  /// having landed over it or being written now.
  public func isLastLanded(_ ticket: Ticket) -> Bool {
    landed.load(ordering: .acquiring) == ticket.number
      && landing.load(ordering: .acquiring) == ticket.number
  }
}

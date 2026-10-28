import Foundation

@testable import MultishellCore

/// A write that stays inside `land` until released, on a thread of its own.
/// Not Dispatch's: it adds no thread while the pool's own fill the cores.
final class HeldWrite: Sendable {
  private let entered = DispatchSemaphore(value: 0)
  private let released = DispatchSemaphore(value: 0)

  init(order: SaveOrder) {
    let ticket = order.issue()
    Thread { [entered, released] in
      order.land(ticket) {
        entered.signal()
        released.wait()
      }
    }.start()
    entered.wait()
  }

  /// Whether `call` returns while the write is held. Held, the write never
  /// ends, so the bound only tells a wait from none.
  func answers(_ call: @escaping @Sendable () -> Void) -> Bool {
    let returned = DispatchSemaphore(value: 0)
    Thread {
      call()
      returned.signal()
    }.start()
    return returned.wait(timeout: .now() + 10) == .success
  }

  func release() {
    released.signal()
  }
}

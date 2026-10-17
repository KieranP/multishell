/// One read at a time per key: one asked for while another runs or waits out
/// its pace is kept, to run once when that one finishes.
struct CoalescedReads<Key: Hashable> {
  private var running: [Key: Task<Void, Never>] = [:]
  private var askedAgain: Set<Key> = []

  func isRunning(_ key: Key) -> Bool { running[key] != nil }

  mutating func start(_ key: Key, _ read: () -> Task<Void, Never>) {
    guard running[key] == nil else {
      askedAgain.insert(key)
      return
    }
    running[key] = read()
  }

  /// Whether another was asked for meanwhile, which the caller runs now.
  mutating func finish(_ key: Key) -> Bool {
    running[key] = nil
    return askedAgain.remove(key) != nil
  }

  mutating func cancel(where isCancelled: (Key) -> Bool) {
    for (key, task) in running where isCancelled(key) {
      task.cancel()
      running[key] = nil
    }
    askedAgain = askedAgain.filter { !isCancelled($0) }
  }
}

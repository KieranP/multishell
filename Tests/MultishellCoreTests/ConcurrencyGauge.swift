/// How many callers are inside at once, and the most there ever were.
actor ConcurrencyGauge {
  private var inside = 0
  private(set) var peak = 0

  func enter() {
    inside += 1
    peak = max(peak, inside)
  }

  func leave() {
    inside -= 1
  }
}

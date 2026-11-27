/// How many callers are inside at once, the most there ever were, and how many came in.
actor ConcurrencyGauge {
  private var inside = 0
  private(set) var peak = 0
  private(set) var entered = 0

  func enter() {
    inside += 1
    entered += 1
    peak = max(peak, inside)
  }

  func leave() {
    inside -= 1
  }
}

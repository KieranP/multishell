import MultishellProcess

extension Sequence<ProcessUsage> {
  /// By footprint, the largest first, a tie by pid so a redraw keeps the order.
  func heaviestFirst() -> [ProcessUsage] {
    sorted { ($0.footprint, $1.pid) > ($1.footprint, $0.pid) }
  }
}

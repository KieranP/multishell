import MultishellProcess

extension Sequence<ProcessUsage> {
  var totalMemory: UInt64 { reduce(0) { $0 + $1.footprint } }
}

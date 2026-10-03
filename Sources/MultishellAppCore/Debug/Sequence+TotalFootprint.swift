import MultishellProcess

extension Sequence<ProcessUsage> {
  var totalFootprint: UInt64 { reduce(0) { $0 + $1.footprint } }
}

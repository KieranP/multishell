extension [Worker] {
  /// How many workers are out, more than the places where an agent named two
  /// alike; a failed one is drawn until swept but is not out. See agents.md.
  var workerCount: Int { reduce(0) { $0 + ($1.hasFailed ? 0 : $1.occurrences) } }

  var failedCount: Int { filter(\.hasFailed).count }
}

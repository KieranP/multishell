import MultishellProcess

extension AppModel {
  /// The app's threads over the range, under their groups, each level in the
  /// order the table's header picked.
  public func debugThreadGroups(
    for range: DebugRange,
    sortedBy sort: DebugTableSort<DebugThreadColumn>,
  ) -> [DebugThreadGroupRow] {
    let samples = shownDebugSnapshot.history.samples(in: range)
    let seconds = samples.reduce(0) { $0 + $1.elapsedSeconds }
    var tallies: [DebugThreadKey: DebugThreadTally] = [:]
    var peakThreadCounts: [DebugThreadGroup: Int] = [:]
    for sample in samples {
      var threadCounts: [DebugThreadGroup: Int] = [:]
      for (key, tally) in sample.threadCPU.byThread {
        tallies[key, default: DebugThreadTally(threadCount: 0, cpuTime: .zero)].merge(tally)
        threadCounts[key.group, default: 0] += tally.threadCount
      }
      peakThreadCounts.merge(threadCounts, uniquingKeysWith: max)
    }
    let rows = tallies.map { key, tally in
      DebugThreadRow(
        key: key,
        tally: tally,
        meanPercent: seconds > 0 ? tally.cpuTime.inSeconds / seconds * 100 : 0,
      )
    }
    let groups = Dictionary(grouping: rows, by: \.key.group).map { group, threads in
      DebugThreadGroupRow(
        group: group,
        threads: sort.ordered(threads),
        threadCount: peakThreadCounts[group] ?? 0,
      )
    }
    return sort.ordered(groups)
  }
}

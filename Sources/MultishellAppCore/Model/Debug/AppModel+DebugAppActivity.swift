extension AppModel {
  /// The app's own work over the range, in the order the table's header
  /// picked; a kind that never ran is left out.
  public func debugAppActivityRows(
    for range: DebugRange,
    sortedBy sort: DebugTableSort<DebugAppActivityColumn>,
  ) -> [DebugAppActivityRow] {
    var reports = DebugWorkTally.empty
    var saves = DebugWorkTally.empty
    for sample in shownDebugSnapshot.history.samples(in: range) {
      reports.merge(sample.stateReports)
      saves.merge(sample.stateSaves)
    }
    let rows = [
      DebugAppActivityRow(kind: .stateReports, tally: reports),
      DebugAppActivityRow(kind: .stateSaves, tally: saves),
    ]
    return sort.ordered(rows.filter { !$0.tally.isEmpty })
  }
}

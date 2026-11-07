import MultishellCore

extension ProgramStatus {
  /// The report as `debug log` shows it, its message left out as the user's own words.
  var logLine: String {
    "\(state) id=\(recordID ?? "-") app=\(app ?? "-") reason=\(blockedReason.map { "\($0)" } ?? "-")"
  }
}

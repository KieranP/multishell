import MultishellCore

extension Worker {
  /// `id` in place of the report's, for one an unnamed start was given.
  init(report: WorkerReport, id: String? = nil) {
    self.init(
      id: id ?? report.id, type: report.type, name: report.name,
      description: report.description, parentID: report.parentID)
  }

  /// What a later report adds about the worker; a field it leaves out stays.
  mutating func adoptDetails(of report: WorkerReport) {
    if let parentID = report.parentID { self.parentID = parentID }
    if let name = report.name { self.name = name }
    if let description = report.description { self.description = description }
  }

  /// Named by a launch or a list before any start of its own. A background
  /// shell sends none, so only other work waits for one.
  mutating func markNamedBeforeStart(isBackgroundShell: Bool) {
    isListedShell = isBackgroundShell
    awaitsStart = !isBackgroundShell
  }
}

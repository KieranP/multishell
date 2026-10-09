extension SessionStateReport {
  /// The roster change the report carries, an older helper's count read as
  /// an unnamed worker starting or ending.
  public var workerChange: WorkerReport? {
    if let worker { return worker }
    switch legacyWorkerCount {
    case .some(let count) where count > 0:
      return WorkerReport(id: WorkerReport.anonymousID, phase: .started)

    case .some(let count) where count < 0:
      return WorkerReport(id: WorkerReport.anonymousID, phase: .ended)

    default:
      return nil
    }
  }

  /// What an app that reads only the count should make of a worker. A tool
  /// call counts for nothing: each would otherwise add a worker to its roster.
  static func legacyCount(of worker: WorkerReport?) -> Int? {
    switch worker?.phase {
    case .started: 1
    case .ended: -1
    case .working, nil: nil
    }
  }
}

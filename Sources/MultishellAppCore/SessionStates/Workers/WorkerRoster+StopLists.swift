import MultishellCore

/// What a Stop's list of the work still out does to the roster.
extension WorkerRoster {
  /// A Stop that lists what is out outranks the hooks: whatever it leaves out
  /// has ended, and whatever it names is out. Returns the ids taken off.
  mutating func keepOnly(_ out: [WorkerReport], shells: [Int32]) -> [String] {
    let listed = Set(out.map(\.id))
    let vouched = withDescendants(of: listed)
    let holding = ancestors(of: vouched).subtracting(vouched)
    let live = Set(shells)
    let gone = workers.filter { worker in
      if let pid = worker.pid { return !live.contains(pid) }
      return worker.id != Worker.overflowID && !worker.hasFailed && !vouched.contains(worker.id)
        && !holding.contains(worker.id)
    }.map(\.id)
    endUnlisted(gone)
    for index in workers.indices {
      if vouched.contains(workers[index].id) { workers[index].wasHeardSinceStop = true }
      if holding.contains(workers[index].id) { workers[index].hasEnded = true }
    }
    let overflowedGone = overflowed.keys.filter { !listed.contains($0) }
    for id in overflowedGone { forget(id) }
    addListed(out)
    recordShells(shells)
    return gone + overflowedGone
  }

  /// A worker's stop lists background work only, so it ends just what an earlier
  /// list named, the stopping worker left to its own report. Returns those.
  mutating func keepOnlyListedOut(_ out: [WorkerReport], stopping stoppingID: String?) -> [String] {
    let listed = Set(out.map(\.id))
    let gone = workers.filter { worker in
      worker.wasListed && !worker.hasFailed && worker.id != stoppingID
        && !listed.contains(worker.id)
    }.map(\.id)
    endUnlisted(gone)
    addListed(out)
    return gone
  }

  /// Work a list leaves out has ended, and a launched worker that never sent
  /// its own stop first was killed, so it is drawn failed until swept.
  private mutating func endUnlisted(_ ids: [String]) {
    let wereAwaitingResume = Set(workers.filter(\.awaitsResume).map(\.id))
    for id in ids {
      guard let index = workers.firstIndex(where: { $0.id == id }),
        !workers[index].awaitsResume || wereAwaitingResume.contains(id)
      else { continue }
      if workers[index].isBackgroundAgent, !workers[index].lastReportWasItsStop {
        workers[index].markFailed()
      } else {
        end(at: index, everyStart: true)
      }
    }
  }

  /// Puts on what a list names that is not out, and marks all it names.
  private mutating func addListed(_ out: [WorkerReport]) {
    let listed = Set(out.map(\.id))
    for worker in out where !isOut(worker.id) {
      var listedWorker = Worker(id: worker.id, type: worker.type)
      listedWorker.markNamedBeforeStart(isBackgroundShell: worker.isBackgroundShell == true)
      add(listedWorker)
    }
    for index in workers.indices where listed.contains(workers[index].id) {
      workers[index].wasListed = true
    }
  }

  /// A Stop vouches only for workers heard from since the last one.
  mutating func markOutAtStop() {
    for index in workers.indices {
      workers[index].wasOutAtStop = workers[index].wasHeardSinceStop
      workers[index].wasHeardSinceStop = false
    }
  }

  /// What a new turn leaves standing: what a Stop saw out, overflow included,
  /// and listed work, which is background work no interrupt ends.
  func keepingOutAtStop() -> WorkerRoster {
    var kept = WorkerRoster()
    let out = Set(
      workers.filter { $0.wasOutAtStop || $0.wasListed || $0.hasFailed }.map(\.id)
    )
    let holding = ancestors(of: out).subtracting(out)
    kept.workers = workers.filter { out.contains($0.id) || holding.contains($0.id) }
    for index in kept.workers.indices where holding.contains(kept.workers[index].id) {
      kept.workers[index].hasEnded = true
    }
    if kept.workers.contains(where: { $0.id == Worker.overflowID }) {
      kept.overflowed = overflowed
    }
    kept.retired = retired
    let keptIDs = Set(kept.workers.map(\.id))
    for worker in workers where !keptIDs.contains(worker.id) { kept.rememberRetired(worker) }
    return kept
  }
}

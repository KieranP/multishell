import Foundation
import MultishellCore

/// The workers one agent still has out, in the order they started; see
/// Docs/design/agents.md.
struct WorkerRoster: Equatable, Sendable {
  var workers: [Worker] = []
  /// Workers past the roster limit by id, all under the one overflow place,
  /// so a tool call is told from a new worker and a stray end from their own.
  var overflowed: [String: Int] = [:]
  /// Workers taken off, newest last, so a child whose parent is named only
  /// after that parent ended is still drawn under it.
  var retired: [Worker] = []

  /// A roster place a report touched, and whether more than one worker was
  /// under it: a start repeated under one id makes which reported unknowable.
  struct Place {
    var id: String
    var isShared = false
  }

  var isEmpty: Bool { workers.isEmpty && overflowed.isEmpty }

  /// Whether anything is still working: a failed row is drawn until swept but
  /// holds no Working.
  var hasWorkOut: Bool { workers.contains { !$0.hasFailed } }

  /// A start or a tool call puts a worker on the roster, its end takes it off.
  /// Returns the place touched; `asking` are the workers with a prompt up.
  @discardableResult
  mutating func record(_ report: WorkerReport, asking: Set<String> = []) -> Place {
    let isAnonymous = report.id == WorkerReport.anonymousID
    switch report.phase {
    case .ended:
      return recordEnd(report, asking: asking)
    case .working where isAnonymous:
      // A tool call names no worker either, so it is one already out, and
      // only a start puts another unnamed place on the roster.
      if let index = workers.lastIndex(where: \.isAnonymous) {
        return place(at: index)
      }
      if overflowedAnonymousID != nil { return overflowPlace }
      return add(Worker(id: Worker.anonymousPrefix + UUID().uuidString, type: report.type))
    case .working where report.isPaused == true:
      return recordOwnStop(report)
    case .started, .working:
      return recordStartOrToolCall(report, isAnonymous: isAnonymous)
    }
  }

  private mutating func recordEnd(_ report: WorkerReport, asking: Set<String>) -> Place {
    if let id = overflowedID(endedBy: report) { return removeFromOverflow(id) }
    guard let index = endingPlace(for: report, asking: asking) else {
      return Place(id: report.id)
    }
    let place = self.place(at: index)
    if report.hasFailed == true {
      workers[index].markFailed()
    } else {
      end(at: index)
    }
    return place
  }

  private mutating func recordStartOrToolCall(
    _ report: WorkerReport, isAnonymous: Bool
  ) -> Place {
    let id = isAnonymous ? Worker.anonymousPrefix + UUID().uuidString : report.id
    guard let index = workers.firstIndex(where: { $0.id == id }) else {
      guard overflowed[id] != nil else {
        var added = Worker(report: report, id: id)
        added.lastReportWasItsStop = report.isPaused == true
        let place = add(added)
        bringBackRetiredParents(of: id)
        return place
      }
      if report.phase == .started { _ = addToOverflow(id) }
      if let overflow = overflowIndex { workers[overflow].wasHeardSinceStop = true }
      return overflowPlace
    }
    // A tool call from one already out says nothing; a second start under
    // its id is a second worker an agent named without an id.
    workers[index].wasHeardSinceStop = true
    workers[index].hasEnded = false
    workers[index].awaitsResume = false
    workers[index].hasFailed = false
    workers[index].failedAt = nil
    workers[index].lastReportWasItsStop = report.isPaused == true
    workers[index].adoptDetails(of: report)
    if report.phase == .started, workers[index].awaitsStart {
      workers[index].awaitsStart = false
      if let type = report.type { workers[index].type = type }
    } else if report.phase == .started {
      workers[index].occurrences += 1
    }
    let place = place(at: index)
    bringBackRetiredParents(of: id)
    return place
  }

  /// A worker's own stop, which hooks may deliver after a list that already
  /// ended it: it then finished, so it is never put back or revived.
  private mutating func recordOwnStop(_ report: WorkerReport) -> Place {
    guard let index = workers.firstIndex(where: { $0.id == report.id }) else {
      return Place(id: report.id)
    }
    guard !workers[index].hasFailed else {
      retire([report.id])
      return Place(id: report.id)
    }
    workers[index].wasHeardSinceStop = true
    workers[index].lastReportWasItsStop = true
    workers[index].adoptDetails(of: report)
    return place(at: index)
  }

  /// Under its launcher from the start. Background work is in every list while
  /// it runs, so the first list to leave it out ends it.
  mutating func recordLaunch(_ report: WorkerReport) {
    if let index = workers.firstIndex(where: { $0.id == report.id }) {
      workers[index].adoptDetails(of: report)
      workers[index].wasListed = true
      workers[index].isBackgroundAgent = report.isBackgroundShell != true
    } else if !isOut(report.id) {
      var launched = Worker(report: report)
      launched.markNamedBeforeStart(isBackgroundShell: report.isBackgroundShell == true)
      launched.wasListed = true
      launched.isBackgroundAgent = report.isBackgroundShell != true
      add(launched)
    }
    bringBackRetiredParents(of: report.id)
  }

  /// A task the agent stopped, and everything under it, which Claude stops
  /// with it, drawn as failed until swept. Returns the ids it marked.
  mutating func recordKill(_ id: String) -> [String] {
    let killed = withDescendants(of: [id])
    for index in workers.indices where killed.contains(workers[index].id) {
      workers[index].markFailed()
    }
    return workers.map(\.id).filter(killed.contains)
  }

  /// Which place an end takes: a named one its own, an unnamed one the
  /// oldest asking. Never nothing, or a leftover holds Done all turn.
  private func endingPlace(for report: WorkerReport, asking: Set<String>) -> Int? {
    guard report.id == WorkerReport.anonymousID else {
      return workers.firstIndex { $0.id == report.id }
    }
    let askingPlace = workers.lastIndex { $0.isAnonymous && asking.contains($0.id) }
    // A background shell's end is its exit, never a hook's.
    return askingPlace ?? workers.lastIndex(where: \.isAnonymous) ?? firstNamedPlace
  }

  var firstNamedPlace: Int? {
    workers.firstIndex {
      !$0.isBackgroundShell && !$0.hasEnded && !$0.hasFailed && $0.id != Worker.overflowID
    }
  }

  func place(at index: Int) -> Place {
    Place(id: workers[index].id, isShared: workers[index].occurrences > 1)
  }

  /// One place per pid, however many Stops name it.
  mutating func recordShells(_ pids: [Int32]) {
    // A Stop that finds one still running has heard from it.
    for index in workers.indices where workers[index].pid.map(pids.contains) == true {
      workers[index].wasHeardSinceStop = true
    }
    var kept = Set(workers.compactMap(\.pid))
    for pid in pids where kept.insert(pid).inserted {
      add(Worker(id: Worker.shellPrefix + String(pid), type: nil, pid: pid))
    }
  }

  func isOut(_ id: String) -> Bool {
    overflowed[id] != nil || workers.contains { $0.id == id }
  }

  /// Past the limit a worker shares one overflow place, so none still out is
  /// dropped. A shell is, its pid having nowhere to go in a shared place.
  @discardableResult
  mutating func add(_ worker: Worker) -> Place {
    let placed = workers.count - (overflowIndex == nil ? 0 : 1)
    guard placed >= SessionStateReport.rosterCapacity else {
      workers.append(worker)
      return Place(id: worker.id)
    }
    guard worker.pid == nil, addToOverflow(worker.id) else { return Place(id: worker.id) }
    return overflowPlace
  }

  /// Takes a worker off wherever it is, every start under its id included.
  mutating func forget(_ id: String) {
    workers.removeAll { $0.id == id }
    for _ in 0..<(overflowed[id] ?? 0) { removeFromOverflow(id) }
    retireEndedWithNothingUnder()
  }

  /// One of a place's occurrences, or with its last the worker itself, which
  /// stays stopped while a worker it launched is out.
  mutating func end(at index: Int, everyStart: Bool = false) {
    if workers[index].occurrences > 1, !everyStart {
      workers[index].occurrences -= 1
    } else if workers.contains(where: { $0.parentID == workers[index].id }) {
      workers[index].occurrences = 1
      workers[index].hasEnded = true
    } else {
      retire([workers[index].id])
    }
  }

  /// Takes the workers off, remembered as retired, and any stopped parent left
  /// holding nothing.
  mutating func retire(_ ids: Set<String>) {
    for worker in workers where ids.contains(worker.id) { remember(worker) }
    workers.removeAll { ids.contains($0.id) }
    retireEndedWithNothingUnder()
  }

  /// One that paused is woken by the end of its own work, so it waits a list.
  private mutating func retireEndedWithNothingUnder() {
    while let index = workers.firstIndex(where: { worker in
      worker.hasEnded && !worker.awaitsResume && !workers.contains { $0.parentID == worker.id }
    }) {
      if workers[index].lastReportWasItsStop {
        workers[index].awaitsResume = true
      } else {
        remember(workers.remove(at: index))
      }
    }
  }
}

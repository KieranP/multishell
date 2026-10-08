import Foundation
import MultishellCore

/// The workers one agent still has out, in the order they started; see
/// Docs/design/agents.md.
struct WorkerRoster: Equatable, Sendable {
  private(set) var workers: [Worker] = []
  /// Workers past the roster limit by id, all under the one overflow place,
  /// so a tool call is told from a new worker and a stray end from their own.
  private(set) var overflowed: [String: Int] = [:]
  /// Workers taken off, newest last, so a child whose parent is named only
  /// after that parent ended is still drawn under it.
  private(set) var ended: [Worker] = []

  /// A roster place a report touched, and whether more than one worker was
  /// under it: a start repeated under one id makes which reported unknowable.
  struct Place {
    var id: String
    var isShared = false
  }

  /// How many ids the overflow place tells apart; a worker past that is dropped.
  private static let overflowLimit = 1024
  /// Far more parents than a fan-out names; the oldest is forgotten past it.
  private static let endedLimit = 64

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
      if let id = overflowedID(endedBy: report) { return removeFromOverflow(id) }
      guard let index = endingPlace(for: report, asking: asking) else {
        return Place(id: report.id)
      }
      let place = self.place(at: index)
      if report.hasFailed == true {
        workers[index].hasFailed = true
        workers[index].failedAt = nil
        workers[index].occurrences = 1
      } else {
        end(at: index)
      }
      return place
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
      let id = isAnonymous ? Worker.anonymousPrefix + UUID().uuidString : report.id
      guard let index = workers.firstIndex(where: { $0.id == id }) else {
        guard overflowed[id] != nil else {
          var added = Worker(
            id: id, type: report.type, name: report.name, description: report.description,
            parentID: report.parentID)
          added.lastReportWasItsStop = report.isPaused == true
          let place = add(added)
          bringBackEndedParents(of: id)
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
      if let parentID = report.parentID { workers[index].parentID = parentID }
      if let name = report.name { workers[index].name = name }
      if let description = report.description { workers[index].description = description }
      if report.phase == .started, workers[index].awaitsStart {
        workers[index].awaitsStart = false
        if let type = report.type { workers[index].type = type }
      } else if report.phase == .started {
        workers[index].occurrences += 1
      }
      let place = place(at: index)
      bringBackEndedParents(of: id)
      return place
    }
  }

  /// A worker's own stop, which hooks may deliver after a list that already
  /// ended it: it then finished, so it is never put back or revived.
  private mutating func recordOwnStop(_ report: WorkerReport) -> Place {
    guard let index = workers.firstIndex(where: { $0.id == report.id }) else {
      return Place(id: report.id)
    }
    guard !workers[index].hasFailed else {
      take([report.id])
      return Place(id: report.id)
    }
    workers[index].wasHeardSinceStop = true
    workers[index].lastReportWasItsStop = true
    if let parentID = report.parentID { workers[index].parentID = parentID }
    if let name = report.name { workers[index].name = name }
    if let description = report.description { workers[index].description = description }
    return place(at: index)
  }

  /// Under its launcher from the start. Background work is in every list while
  /// it runs, so the first list to leave it out ends it.
  mutating func recordLaunch(_ report: WorkerReport) {
    if let index = workers.firstIndex(where: { $0.id == report.id }) {
      if let parentID = report.parentID { workers[index].parentID = parentID }
      if let name = report.name { workers[index].name = name }
      if let description = report.description { workers[index].description = description }
      workers[index].wasListed = true
      workers[index].wasLaunchedInBackground = report.isBackgroundShell != true
    } else if !isOut(report.id) {
      var launched = Worker(
        id: report.id, type: report.type, name: report.name, description: report.description,
        parentID: report.parentID)
      launched.isListedShell = report.isBackgroundShell == true
      launched.awaitsStart = report.isBackgroundShell != true
      launched.wasListed = true
      launched.wasLaunchedInBackground = report.isBackgroundShell != true
      add(launched)
    }
    bringBackEndedParents(of: report.id)
  }

  /// A task the agent stopped, and everything under it, which Claude stops
  /// with it, drawn as failed until swept. Returns the ids it marked.
  mutating func recordKill(_ id: String) -> [String] {
    let killed = withDescendants(of: [id])
    for index in workers.indices where killed.contains(workers[index].id) {
      workers[index].hasFailed = true
      workers[index].failedAt = nil
      workers[index].occurrences = 1
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

  private var firstNamedPlace: Int? {
    workers.firstIndex {
      !$0.isBackgroundShell && !$0.hasEnded && !$0.hasFailed && $0.id != Worker.overflowID
    }
  }

  /// The overflowed worker an end takes, in `endingPlace`'s order: an unnamed
  /// end takes an unnamed one first, and any only where no named place is left.
  private func overflowedID(endedBy report: WorkerReport) -> String? {
    guard report.id == WorkerReport.anonymousID else {
      return overflowed[report.id] == nil ? nil : report.id
    }
    guard !workers.contains(where: \.isAnonymous) else { return nil }
    return overflowedAnonymousID ?? (firstNamedPlace == nil ? overflowed.keys.first : nil)
  }

  private var overflowedAnonymousID: String? {
    overflowed.keys.first { $0.hasPrefix(Worker.anonymousPrefix) }
  }

  private var overflowIndex: Int? {
    workers.firstIndex { $0.id == Worker.overflowID }
  }

  private var overflowPlace: Place {
    overflowIndex.map(place(at:)) ?? Place(id: Worker.overflowID)
  }

  private func place(at index: Int) -> Place {
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
      if workers[index].wasLaunchedInBackground, !workers[index].lastReportWasItsStop {
        workers[index].hasFailed = true
        workers[index].failedAt = nil
        workers[index].occurrences = 1
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
      listedWorker.isListedShell = worker.isBackgroundShell == true
      listedWorker.awaitsStart = worker.isBackgroundShell != true
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
      workers.filter { $0.wasOutAtStop || $0.wasListed || $0.hasFailed }.map(\.id))
    let holding = ancestors(of: out).subtracting(out)
    kept.workers = workers.filter { out.contains($0.id) || holding.contains($0.id) }
    for index in kept.workers.indices where holding.contains(kept.workers[index].id) {
      kept.workers[index].hasEnded = true
    }
    if kept.workers.contains(where: { $0.id == Worker.overflowID }) {
      kept.overflowed = overflowed
    }
    kept.ended = ended
    let keptIDs = Set(kept.workers.map(\.id))
    for worker in workers where !keptIDs.contains(worker.id) { kept.remember(worker) }
    return kept
  }

  private func isOut(_ id: String) -> Bool {
    overflowed[id] != nil || workers.contains { $0.id == id }
  }

  /// Past the limit a worker shares one overflow place, so none still out is
  /// dropped. A shell is, its pid having nowhere to go in a shared place.
  @discardableResult
  private mutating func add(_ worker: Worker) -> Place {
    let placed = workers.count - (overflowIndex == nil ? 0 : 1)
    guard placed >= SessionStateReport.rosterCapacity else {
      workers.append(worker)
      return Place(id: worker.id)
    }
    guard worker.pid == nil, addToOverflow(worker.id) else { return Place(id: worker.id) }
    return overflowPlace
  }

  /// `false` for a new id once the overflow place holds `overflowLimit` of them.
  private mutating func addToOverflow(_ id: String) -> Bool {
    guard overflowed[id] != nil || overflowed.count < Self.overflowLimit else { return false }
    overflowed[id, default: 0] += 1
    if let overflow = overflowIndex {
      workers[overflow].occurrences += 1
    } else {
      workers.append(Worker(id: Worker.overflowID, type: nil))
    }
    return true
  }

  /// Takes a worker off wherever it is, every start under its id included.
  mutating func forget(_ id: String) {
    workers.removeAll { $0.id == id }
    for _ in 0..<(overflowed[id] ?? 0) { removeFromOverflow(id) }
    takeEndedWithNothingUnder()
  }

  /// One of a place's occurrences, or with its last the worker itself, which
  /// stays stopped while a worker it launched is out.
  private mutating func end(at index: Int, everyStart: Bool = false) {
    if workers[index].occurrences > 1, !everyStart {
      workers[index].occurrences -= 1
    } else if workers.contains(where: { $0.parentID == workers[index].id }) {
      workers[index].occurrences = 1
      workers[index].hasEnded = true
    } else {
      take([workers[index].id])
    }
  }

  /// Takes the workers off, remembered as ended, and any stopped parent left
  /// holding nothing.
  private mutating func take(_ ids: Set<String>) {
    for worker in workers where ids.contains(worker.id) { remember(worker) }
    workers.removeAll { ids.contains($0.id) }
    takeEndedWithNothingUnder()
  }

  /// One that paused is woken by the end of its own work, so it waits a list.
  private mutating func takeEndedWithNothingUnder() {
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

  private mutating func remember(_ worker: Worker) {
    guard worker.pid == nil, worker.id != Worker.overflowID else { return }
    ended.removeAll { $0.id == worker.id }
    ended.append(worker)
    if ended.count > Self.endedLimit { ended.removeFirst() }
  }

  /// A parent named after it ended goes back on above its child, stopped, and
  /// so does its own, so the child is drawn where it belongs.
  private mutating func bringBackEndedParents(of id: String) {
    var childID = id
    while let childIndex = workers.firstIndex(where: { $0.id == childID }),
      let parentID = workers[childIndex].parentID, !isOut(parentID),
      workers.count < SessionStateReport.rosterCapacity,
      let endedIndex = ended.lastIndex(where: { $0.id == parentID })
    {
      var parent = ended.remove(at: endedIndex)
      parent.hasEnded = true
      parent.occurrences = 1
      workers.insert(parent, at: childIndex)
      childID = parentID
    }
  }

  @discardableResult
  private mutating func removeFromOverflow(_ id: String) -> Place {
    let place = overflowPlace
    overflowed[id] = overflowed[id].flatMap { $0 > 1 ? $0 - 1 : nil }
    if let overflow = overflowIndex { removeOne(at: overflow) }
    return place
  }

  /// One of a place's occurrences, and the place itself with its last.
  private mutating func removeOne(at index: Int) {
    if workers[index].occurrences > 1 {
      workers[index].occurrences -= 1
    } else {
      workers.remove(at: index)
    }
  }

  var hasUnstampedStarts: Bool {
    workers.contains { $0.since == nil || ($0.hasFailed && $0.failedAt == nil) }
  }

  /// A start's time, and a failure's, which the sweep counts from.
  mutating func stampStarts(at now: Date) {
    for index in workers.indices {
      if workers[index].since == nil { workers[index].since = now }
      if workers[index].hasFailed, workers[index].failedAt == nil {
        workers[index].failedAt = now
      }
    }
  }

  /// The earliest a failed row is due to go, `nil` with none stamped.
  var earliestFailure: Date? { workers.compactMap(\.failedAt).min() }

  /// Takes off the failed rows stamped before `cutoff`. Returns their ids.
  mutating func removeFailed(before cutoff: Date) -> [String] {
    let gone = workers.filter { $0.hasFailed && ($0.failedAt.map { $0 < cutoff } ?? false) }
      .map(\.id)
    take(Set(gone))
    return gone
  }
}

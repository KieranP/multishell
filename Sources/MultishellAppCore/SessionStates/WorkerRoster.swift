import Foundation
import MultishellCore

/// The workers one agent still has out, in the order they started; see
/// Docs/design/agents.md.
struct WorkerRoster: Equatable, Sendable {
  private(set) var workers: [Worker] = []
  /// Workers past the roster limit by id, all under the one overflow place,
  /// so a tool call is told from a new worker and a stray end from their own.
  private(set) var overflowed: [String: Int] = [:]

  /// A roster place a report touched, and whether more than one worker was
  /// under it: a start repeated under one id makes which reported unknowable.
  struct Place {
    var id: String
    var isShared = false
  }

  /// How many ids the overflow place tells apart; a worker past that is dropped.
  private static let overflowLimit = 1024

  var isEmpty: Bool { workers.isEmpty && overflowed.isEmpty }

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
      removeOne(at: index)
      return place
    case .working where isAnonymous:
      // A tool call names no worker either, so it is one already out, and
      // only a start puts another unnamed place on the roster.
      if let index = workers.lastIndex(where: \.isAnonymous) {
        return place(at: index)
      }
      if overflowedAnonymousID != nil { return overflowPlace }
      return add(Worker(id: Worker.anonymousPrefix + UUID().uuidString, type: report.type))
    case .started, .working:
      let id = isAnonymous ? Worker.anonymousPrefix + UUID().uuidString : report.id
      guard let index = workers.firstIndex(where: { $0.id == id }) else {
        guard overflowed[id] != nil else { return add(Worker(id: id, type: report.type)) }
        if report.phase == .started { _ = addToOverflow(id) }
        if let overflow = overflowIndex { workers[overflow].wasHeardSinceStop = true }
        return overflowPlace
      }
      // A tool call from one already out says nothing; a second start under
      // its id is a second worker an agent named without an id.
      workers[index].wasHeardSinceStop = true
      if report.phase == .started, workers[index].awaitsStart {
        workers[index].awaitsStart = false
        if let type = report.type { workers[index].type = type }
      } else if report.phase == .started {
        workers[index].occurrences += 1
      }
      return place(at: index)
    }
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
    workers.firstIndex { !$0.isBackgroundShell && $0.id != Worker.overflowID }
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
    let live = Set(shells)
    let gone = workers.filter { worker in
      if let pid = worker.pid { return !live.contains(pid) }
      return worker.id != Worker.overflowID && !listed.contains(worker.id)
    }.map(\.id)
    workers.removeAll { gone.contains($0.id) }
    for index in workers.indices where listed.contains(workers[index].id) {
      workers[index].wasHeardSinceStop = true
    }
    let overflowedGone = overflowed.keys.filter { !listed.contains($0) }
    for id in overflowedGone { forget(id) }
    for worker in out where !isOut(worker.id) {
      var listedWorker = Worker(id: worker.id, type: worker.type)
      listedWorker.isListedShell = worker.isBackgroundShell == true
      listedWorker.awaitsStart = worker.isBackgroundShell != true
      add(listedWorker)
    }
    recordShells(shells)
    return gone + overflowedGone
  }

  /// A Stop vouches only for workers heard from since the last one.
  mutating func markOutAtStop() {
    for index in workers.indices {
      workers[index].wasOutAtStop = workers[index].wasHeardSinceStop
      workers[index].wasHeardSinceStop = false
    }
  }

  /// Only the workers a Stop saw out, which a new turn leaves standing, the
  /// overflowed ones with the overflow place that stands for them.
  func keepingOutAtStop() -> WorkerRoster {
    var kept = WorkerRoster()
    kept.workers = workers.filter(\.wasOutAtStop)
    if kept.workers.contains(where: { $0.id == Worker.overflowID }) {
      kept.overflowed = overflowed
    }
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

  var hasUnstampedStarts: Bool { workers.contains { $0.since == nil } }

  mutating func stampStarts(at now: Date) {
    for index in workers.indices where workers[index].since == nil {
      workers[index].since = now
    }
  }
}

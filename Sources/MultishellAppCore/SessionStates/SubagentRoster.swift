import Foundation
import MultishellCore

/// The workers one agent still has out, in the order they started; see
/// Docs/design/agents.md.
struct SubagentRoster: Equatable, Sendable {
  private(set) var subagents: [Subagent] = []
  /// Workers past the roster limit by id, all under the one overflow place,
  /// so a tool call is told from a new worker and a stray end from their own.
  private(set) var folded: [String: Int] = [:]

  /// A roster place a report touched, and whether more than one worker was
  /// under it: a start repeated under one id makes which reported unknowable.
  struct Place {
    var id: String
    var isShared = false
  }

  /// How many ids the overflow place tells apart; a worker past that is dropped.
  static let foldLimit = 1024

  var isEmpty: Bool { subagents.isEmpty && folded.isEmpty }

  /// A start or a tool call puts a worker on the roster, its end takes it off.
  /// Returns the place touched; `asking` are the workers with a prompt up.
  @discardableResult
  mutating func record(_ report: SubagentReport, asking: Set<String> = []) -> Place {
    let isAnonymous = report.id == SubagentReport.anonymousID
    switch report.phase {
    case .ended:
      if let id = foldedID(endedBy: report) { return unfold(id) }
      guard let index = endingPlace(for: report, asking: asking) else {
        return Place(id: report.id)
      }
      let place = self.place(at: index)
      if subagents[index].occurrences > 1 {
        subagents[index].occurrences -= 1
      } else {
        subagents.remove(at: index)
      }
      return place
    case .working where isAnonymous:
      // A tool call names no worker either, so it is one already out, and
      // only a start puts another unnamed place on the roster.
      if let index = subagents.lastIndex(where: \.isAnonymous) {
        return place(at: index)
      }
      if foldedAnonymousID != nil { return overflowPlace }
      return add(Subagent(id: Subagent.anonymousPrefix + UUID().uuidString, type: report.type))
    case .started, .working:
      let id = isAnonymous ? Subagent.anonymousPrefix + UUID().uuidString : report.id
      guard let index = subagents.firstIndex(where: { $0.id == id }) else {
        guard folded[id] != nil else { return add(Subagent(id: id, type: report.type)) }
        if report.phase == .started { _ = fold(id) }
        return overflowPlace
      }
      // A tool call from one already out says nothing; a second start under
      // its id is a second worker an agent named without an id.
      if report.phase == .started { subagents[index].occurrences += 1 }
      return place(at: index)
    }
  }

  /// Which place an end takes: a named one its own, an unnamed one the
  /// oldest asking. Never nothing, or a leftover holds Done all turn.
  private func endingPlace(for report: SubagentReport, asking: Set<String>) -> Int? {
    guard report.id == SubagentReport.anonymousID else {
      return subagents.firstIndex { $0.id == report.id }
    }
    let askingPlace = subagents.lastIndex { $0.isAnonymous && asking.contains($0.id) }
    // A background shell's end is its exit, never a hook's.
    return askingPlace ?? subagents.lastIndex(where: \.isAnonymous) ?? firstNamedPlace
  }

  private var firstNamedPlace: Int? {
    subagents.firstIndex { $0.pid == nil && $0.id != Subagent.overflowID }
  }

  /// The folded worker an end takes, in `endingPlace`'s order: an unnamed
  /// end takes an unnamed one first, and any only where no named place is left.
  private func foldedID(endedBy report: SubagentReport) -> String? {
    guard report.id == SubagentReport.anonymousID else {
      return folded[report.id] == nil ? nil : report.id
    }
    guard !subagents.contains(where: \.isAnonymous) else { return nil }
    return foldedAnonymousID ?? (firstNamedPlace == nil ? folded.keys.first : nil)
  }

  private var foldedAnonymousID: String? {
    folded.keys.first { $0.hasPrefix(Subagent.anonymousPrefix) }
  }

  private var overflowIndex: Int? {
    subagents.firstIndex { $0.id == Subagent.overflowID }
  }

  private var overflowPlace: Place {
    overflowIndex.map(place(at:)) ?? Place(id: Subagent.overflowID)
  }

  private func place(at index: Int) -> Place {
    Place(id: subagents[index].id, isShared: subagents[index].occurrences > 1)
  }

  /// One place per pid, however many Stops name it.
  mutating func keepShells(_ pids: [Int32]) {
    var kept = Set(subagents.compactMap(\.pid))
    for pid in pids where kept.insert(pid).inserted {
      add(Subagent(id: Subagent.shellPrefix + String(pid), type: nil, pid: pid))
    }
  }

  /// Past the limit a worker shares one overflow place, so none still out is
  /// dropped. A shell is, its pid having nowhere to go in a shared place.
  @discardableResult
  private mutating func add(_ worker: Subagent) -> Place {
    let placed = subagents.count - (overflowIndex == nil ? 0 : 1)
    guard placed >= SessionStateReport.maximumWorkerCount else {
      subagents.append(worker)
      return Place(id: worker.id)
    }
    guard worker.pid == nil, fold(worker.id) else { return Place(id: worker.id) }
    return overflowPlace
  }

  /// `false` for a new id once the overflow place holds `foldLimit` of them.
  private mutating func fold(_ id: String) -> Bool {
    guard folded[id] != nil || folded.count < Self.foldLimit else { return false }
    folded[id, default: 0] += 1
    if let overflow = overflowIndex {
      subagents[overflow].occurrences += 1
    } else {
      subagents.append(Subagent(id: Subagent.overflowID, type: nil))
    }
    return true
  }

  /// Takes a worker off wherever it is, every start under its id included.
  mutating func forget(_ id: String) {
    subagents.removeAll { $0.id == id }
    for _ in 0..<(folded[id] ?? 0) { unfold(id) }
  }

  @discardableResult
  private mutating func unfold(_ id: String) -> Place {
    let place = overflowPlace
    folded[id] = folded[id].flatMap { $0 > 1 ? $0 - 1 : nil }
    if let overflow = overflowIndex {
      if subagents[overflow].occurrences > 1 {
        subagents[overflow].occurrences -= 1
      } else {
        subagents.remove(at: overflow)
      }
    }
    return place
  }

  var hasUnstampedStarts: Bool { subagents.contains { $0.since == nil } }

  mutating func stampStarts(at now: Date) {
    for index in subagents.indices where subagents[index].since == nil {
      subagents[index].since = now
    }
  }
}

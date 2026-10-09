import MultishellCore

/// The one place every worker past the roster limit shares.
extension WorkerRoster {
  /// How many ids the overflow place tells apart; a worker past that is dropped.
  static let overflowLimit = 1024

  var overflowedAnonymousID: String? {
    overflowed.keys.first { $0.hasPrefix(Worker.anonymousPrefix) }
  }

  var overflowIndex: Int? {
    workers.firstIndex { $0.id == Worker.overflowID }
  }

  var overflowPlace: Place {
    overflowIndex.map(place(at:)) ?? Place(id: Worker.overflowID)
  }

  /// The overflowed worker an end takes, in `endingIndex`'s order: an unnamed
  /// end takes an unnamed one first, and any only where no named place is left.
  func overflowedID(endedBy report: WorkerReport) -> String? {
    guard report.id == WorkerReport.anonymousID else {
      return overflowed[report.id] == nil ? nil : report.id
    }
    guard !workers.contains(where: \.isAnonymous) else { return nil }
    return overflowedAnonymousID ?? (firstNamedIndex == nil ? overflowed.keys.first : nil)
  }

  /// `false` for a new id once the overflow place holds `overflowLimit` of them.
  mutating func addToOverflow(_ id: String) -> Bool {
    guard overflowed[id] != nil || overflowed.count < Self.overflowLimit else { return false }
    overflowed[id, default: 0] += 1
    if let overflow = overflowIndex {
      workers[overflow].occurrences += 1
    } else {
      workers.append(Worker(id: Worker.overflowID, type: nil))
    }
    return true
  }

  @discardableResult
  mutating func removeFromOverflow(_ id: String) -> Place {
    let place = overflowPlace
    overflowed[id] = overflowed[id].flatMap { $0 > 1 ? $0 - 1 : nil }
    if let overflow = overflowIndex { removeOne(at: overflow) }
    return place
  }

  /// One of a place's occurrences, and the place itself with its last.
  mutating func removeOne(at index: Int) {
    if workers[index].occurrences > 1 {
      workers[index].occurrences -= 1
    } else {
      workers.remove(at: index)
    }
  }
}

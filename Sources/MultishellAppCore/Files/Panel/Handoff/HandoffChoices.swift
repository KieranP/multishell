/// One worktree's checkboxes on the PR and CI pages and what each Send carried.
/// Runtime state; see Docs/design/services/send-feedback.md.
struct HandoffChoices: Equatable, Sendable {
  /// Where the user set a box, back to how it starts included.
  private var picks: [HandoffItemID: Bool] = [:]
  private var sentTo: [HandoffItemID: String] = [:]

  func state(of candidate: HandoffCandidate) -> HandoffItemState {
    if let agentName = sentTo[candidate.id] { return .sent(agentName: agentName) }
    return (picks[candidate.id] ?? candidate.startsChecked) ? .checked : .unchecked
  }

  /// `nil` where nothing is left to send, so the step draws no box.
  func groupState(of candidates: [HandoffCandidate]) -> HandoffGroupState? {
    let unsent = candidates.filter { sentTo[$0.id] == nil }
    guard !unsent.isEmpty else { return nil }
    let checked = unsent.count { state(of: $0).isChecked }
    if checked == unsent.count { return .checked }
    return checked == 0 ? .unchecked : .mixed
  }

  func checked(among candidates: [HandoffCandidate]) -> [HandoffCandidate] {
    candidates.filter { state(of: $0).isChecked }
  }

  mutating func set(_ id: HandoffItemID, checked: Bool) {
    picks[id] = checked
  }

  /// Every unsent item unchecked where all were checked, else every one checked,
  /// as a click on AppKit's mixed checkbox turns it on.
  mutating func toggleGroup(_ candidates: [HandoffCandidate]) {
    let checksAll = groupState(of: candidates) != .checked
    for candidate in candidates where sentTo[candidate.id] == nil {
      picks[candidate.id] = checksAll
    }
  }

  mutating func markSent(_ ids: [HandoffItemID], to agentName: String) {
    for id in ids {
      sentTo[id] = agentName
      picks[id] = nil
    }
  }

  /// Keeps only what `source` lists now, other reads' keys untouched: each push,
  /// rerun or reply makes new keys.
  mutating func keepOnly(_ listed: Set<HandoffItemID>, from source: HandoffItemSource) {
    picks = picks.filter { $0.key.source != source || listed.contains($0.key) }
    sentTo = sentTo.filter { $0.key.source != source || listed.contains($0.key) }
  }

  /// A click on the sent bubble: back to a checked box, to send it again.
  mutating func unmarkSent(_ id: HandoffItemID) {
    sentTo[id] = nil
    picks[id] = true
  }
}

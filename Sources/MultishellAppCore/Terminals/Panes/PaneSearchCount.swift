/// What the engine last said its search found in a pane: the matches, and
/// which is selected. `nil` where it has not said, or the search ended.
struct PaneSearchCount: Equatable, Sendable {
  private(set) var total: Int?
  /// The engine's index, which counts from the match nearest the prompt.
  private(set) var selected: Int?
  /// The match a step moved off, which the bar shows until the engine names
  /// the next a turn later, or its count blinks on every Return.
  private var selectedBeforeStep: Int?
  /// Searches replaced but not yet ended by the engine's 0, or its no total as an
  /// emptied find text stops it, before which every count is theirs; terminals/find.md.
  private var replacedSearchEndsAwaited: Int

  var matchCount: FindMatchCount? {
    guard let total else { return nil }
    let shownSelected = Self.match(selected ?? selectedBeforeStep, within: total)
    return FindMatchCount(position: shownSelected.map { total - $0 }, total: total)
  }

  /// `selected` unless the total no longer holds it, and `nil` mid-step, which `panes find` waits on.
  var selectedWithinTotal: Int? {
    guard let total else { return selected }
    return Self.match(selected, within: total)
  }

  init(replacedSearchEndsAwaited: Int = 0) {
    self.replacedSearchEndsAwaited = replacedSearchEndsAwaited
  }

  /// A switch to the alternate screen posts its total but no cleared match.
  private static func match(_ match: Int?, within total: Int) -> Int? {
    match.flatMap { $0 < total ? $0 : nil }
  }

  /// A new search's count starts empty, still awaiting the ends of the searches
  /// it and those before it replaced. `nil` with none to await.
  static func forNewSearch(after previous: Self?, endingOne: Bool) -> Self? {
    let endsAwaited = (previous?.replacedSearchEndsAwaited ?? 0) + (endingOne ? 1 : 0)
    return endsAwaited > 0 ? Self(replacedSearchEndsAwaited: endsAwaited) : nil
  }

  mutating func noteTotal(_ total: Int?) {
    guard replacedSearchEndsAwaited == 0 else {
      if total == nil || total == 0 { replacedSearchEndsAwaited -= 1 }
      return
    }
    self.total = total
  }

  mutating func noteSelected(_ match: Int?) {
    guard replacedSearchEndsAwaited == 0 else { return }
    selected = match
    selectedBeforeStep = nil
  }

  /// Drops `selected` until the engine names the new match, which `panes find` waits for.
  mutating func noteStep() {
    guard let selected else { return }
    selectedBeforeStep = selected
    self.selected = nil
  }
}

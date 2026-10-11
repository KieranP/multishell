/// What the engine last said its search found in a pane: the matches, and
/// which is selected. `nil` where it has not said, or the search ended.
struct PaneSearchCount: Equatable, Sendable {
  var total: Int?
  var selected: Int?
}

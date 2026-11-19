/// A pane's, file tab's or All changes tab's find bar, as `panes show` and `tabs show` print it.
struct FindBarDescription: Encodable, Equatable {
  let text: String
  /// `nil` until the engine has counted, or a hidden file or All changes tab's rows are read.
  let total: Int?
  /// Which match is selected, from 0: a file's first as its find opens, a pane's
  /// `nil` before a step.
  let selected: Int?
}

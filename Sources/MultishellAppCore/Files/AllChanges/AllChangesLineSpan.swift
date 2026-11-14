import MultishellCore

/// Lines of one file kept open inside a fold, by their number on one side: a
/// fold the user opened, or a comment's lines and two either side.
struct AllChangesLineSpan: Hashable, Sendable {
  let side: DiffSide
  let lines: ClosedRange<Int>
}

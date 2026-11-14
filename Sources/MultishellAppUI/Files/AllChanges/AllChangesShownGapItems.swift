import MultishellAppCore
import MultishellCore

/// What the All changes tab's headers, folds and notices were last hosted
/// from, so an update that moved none of it hosts nothing again.
struct AllChangesShownGapItems: Equatable {
  let document: AllChangesDocument
  let pendingComments: [String: Int]
  let theme: Theme
}

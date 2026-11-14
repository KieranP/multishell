import MultishellCore

/// What an All changes tab's document is built from. The lines held open are
/// kept as their sources, comparing which costs less than working them out.
struct AllChangesDocumentInputs: Equatable {
  let reading: AllChangesReading
  let collapsed: Set<String>
  let openedFolds: [String: [AllChangesLineSpan]]
  let reviewComments: [ReviewComment]
  let reviewComposer: ReviewComposer?
  let scope: ChangeScope?
  let layout: FileTabLayout
}

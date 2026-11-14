/// An All changes tab's document and what it was built from, so a render that
/// finds none of it moved reuses the document.
struct AllChangesDocumentCacheEntry {
  let inputs: AllChangesDocumentInputs
  let heldOpen: [String: [AllChangesLineSpan]]
  let document: AllChangesDocument

  /// Whether the document lays out `inputs` too: a comment's text or state can
  /// move while the lines held open stay.
  func laysOut(
    _ inputs: AllChangesDocumentInputs,
    holdingOpen heldOpen: [String: [AllChangesLineSpan]],
  ) -> Bool {
    inputs.reading == self.inputs.reading && inputs.collapsed == self.inputs.collapsed
      && inputs.layout == self.inputs.layout && heldOpen == self.heldOpen
  }
}

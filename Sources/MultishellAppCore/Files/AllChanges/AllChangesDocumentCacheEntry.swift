import MultishellCore

/// An All changes tab's document and what it was built from, so a render that
/// finds none of it moved reuses the document.
struct AllChangesDocumentCacheEntry {
  let reading: AllChangesReading
  let collapsed: Set<String>
  let heldOpen: [String: [AllChangesLineSpan]]
  let layout: FileTabLayout
  let document: AllChangesDocument
}

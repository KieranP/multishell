/// A file of the All changes list as the list keeps its view: the path, and
/// whether the view shows Split's two columns, so a change of kind builds anew.
struct AllChangesFileKey: Hashable {
  let path: String
  let isSplit: Bool
}

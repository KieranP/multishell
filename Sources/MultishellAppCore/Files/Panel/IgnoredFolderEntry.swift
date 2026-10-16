/// One entry of an ignored folder the panel opened, read from disk one level
/// at a time: git lists none of what it ignores below the folder.
struct IgnoredFolderEntry: Hashable, Sendable {
  let name: String
  let isFolder: Bool
}

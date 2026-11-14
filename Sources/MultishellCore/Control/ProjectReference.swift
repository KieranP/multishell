/// How a request names a project: by its `ControlID`, or as the one holding the
/// directory the helper ran in, a worktree of it or a folder inside one.
public enum ProjectReference: Codable, Equatable, Sendable {
  case holding(directory: String)
  case id(String)
}

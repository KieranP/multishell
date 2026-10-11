/// One project as `multishell projects list` prints it, by its `ControlID`.
struct ProjectEntry: Encodable, Equatable {
  let id: String
  let name: String
  let path: String
  let isMissing: Bool
  let worktreeCount: Int
}

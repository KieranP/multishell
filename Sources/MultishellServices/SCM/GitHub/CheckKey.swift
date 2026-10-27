/// A check by its workflow and name, which is what a rerun keeps and what
/// `gh pr checks --required` names it by.
struct CheckKey: Hashable {
  let workflow: String?
  let name: String
}

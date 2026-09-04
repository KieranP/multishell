import MultishellCore

/// What the New Worktree sheet decides, apart from the view so the rules are
/// testable: when Create is allowed, what git is asked for, and what a
/// project switch or a mode switch does to the fields.
struct NewWorktreeDraft: Equatable {
  var projectID: Project.ID?
  var branch = ""
  var createBranch = true
  var baseBranch = ""
  var branches: [String] = []
  var remoteBranches: [String] = []
  var hasCommits = true
  var isCreating = false
  /// What was typed in new-branch mode, kept across a visit to the
  /// existing-branch picker so coming back restores it, even while a load
  /// is still running and there are no branches to compare against.
  private var typedBranch = ""

  /// The project whose branches are the ones on screen. Create waits for it
  /// to match the picker, so a load still running, or one that was cancelled
  /// by a switch, can never enable it against the wrong project's lists.
  private(set) var loadedProjectID: Project.ID?

  init(projectID: Project.ID?) {
    self.projectID = projectID
  }

  /// The picker landed on a project; nothing is known about it yet. The
  /// typed branch name is the user's and stays.
  mutating func beginLoading() {
    branches = []
    remoteBranches = []
    baseBranch = ""
    hasCommits = true
    loadedProjectID = nil
  }

  /// What git said about `id`. Ignored when the picker has moved on since
  /// the read began. `checkedOut` is the branches the project's worktrees
  /// already have, which the existing-branch list must not offer.
  mutating func finishLoading(
    _ id: Project.ID,
    hasCommits: Bool,
    branches: [String],
    remoteBranches: [String],
    currentBranch: String,
    checkedOut: Set<String>
  ) {
    guard id == projectID else { return }
    self.hasCommits = hasCommits
    self.branches = branches
    self.remoteBranches = remoteBranches
    baseBranch = currentBranch
    // Recorded before the fix-up below, which reads the available branches
    // and sees none for a project not yet marked loaded.
    loadedProjectID = id
    if !createBranch, !availableBranches(checkedOut: checkedOut).contains(branch) {
      branch = availableBranches(checkedOut: checkedOut).first ?? ""
    }
  }

  /// Git refuses to check a branch out twice, so those are not offered.
  func availableBranches(checkedOut: Set<String>) -> [String] {
    guard loadedProjectID != nil else { return [] }
    return branches.filter { !checkedOut.contains($0) }
  }

  /// The field and the picker share `branch`. Leaving new-branch mode puts
  /// the typed name aside and picks an existing branch; coming back restores
  /// what was typed, never what was picked, which would be a duplicate.
  mutating func modeChanged(checkedOut: Set<String>) {
    if createBranch {
      branch = typedBranch
    } else {
      typedBranch = branch
      let available = availableBranches(checkedOut: checkedOut)
      if !available.contains(branch) { branch = available.first ?? "" }
    }
  }

  /// A project removed from the sidebar while the sheet is up goes back to
  /// the placeholder rather than a selection nothing in the list matches.
  mutating func projectsChanged(to ids: [Project.ID]) {
    if let projectID, !ids.contains(projectID) { self.projectID = nil }
  }

  func canCreate(checkedOut: Set<String>) -> Bool {
    guard let projectID, loadedProjectID == projectID, hasCommits, !isCreating else {
      return false
    }
    return createBranch
      ? !branch.trimmingCharacters(in: .whitespaces).isEmpty
      : availableBranches(checkedOut: checkedOut).contains(branch)
  }

  /// What the new branch starts from; `nil` lets git use HEAD. Never the
  /// empty string a cleared field would otherwise send.
  var startPoint: String? {
    createBranch && !baseBranch.isEmpty ? baseBranch : nil
  }

  /// Picker labels. A folder name alone, unless another project shares it,
  /// when the path tells them apart.
  static func labels(for projects: [Project]) -> [Project.ID: String] {
    var count: [String: Int] = [:]
    for project in projects { count[project.name, default: 0] += 1 }
    return Dictionary(
      uniqueKeysWithValues: projects.map { project in
        let label =
          count[project.name] == 1
          ? project.name
          : "\(project.name)  (\(project.path.path.abbreviatingHomeDirectory()))"
        return (project.id, label)
      })
  }
}

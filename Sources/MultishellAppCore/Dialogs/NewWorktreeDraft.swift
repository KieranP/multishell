import Foundation
import MultishellCore
import MultishellGitKit

/// What the New Worktree sheet decides: when Create is allowed, what git is
/// asked for, and what a project or mode switch does to the fields.
public struct NewWorktreeDraft: Equatable, Sendable {
  public var projectID: Project.ID?
  public var branch = ""
  public var createBranch = true
  public var baseBranch = ""
  public var localBranches: [String] = []
  public var remoteBranches: [String] = []
  public var hasCommits = true
  public var isCreating = false
  /// What was typed in new-branch mode, kept across a visit to the
  /// existing-branch picker so coming back restores it.
  private var typedBranch = ""

  /// The project whose branches are on screen. Create waits for it to match
  /// the picker, so a stale load cannot enable it.
  private(set) var loadedProjectID: Project.ID?

  public init(projectID: Project.ID?) {
    self.projectID = projectID
  }

  /// The picker landed on a project; nothing is known about it yet. The
  /// typed branch name is the user's and stays.
  public mutating func beginLoading() {
    localBranches = []
    remoteBranches = []
    baseBranch = ""
    hasCommits = true
    loadedProjectID = nil
  }

  /// What git said about `id`, ignored once the picker has moved on.
  /// `checkedOut` is what the existing-branch list must not offer.
  public mutating func finishLoading(
    _ id: Project.ID, with read: NewWorktreeBranches, checkedOut: Set<String>
  ) {
    guard id == projectID else { return }
    hasCommits = read.hasCommits
    localBranches = read.localBranches
    remoteBranches = read.remoteBranches
    baseBranch = read.currentBranch
    // Recorded before the fix-up below, which reads the available branches
    // and sees none for a project not yet marked loaded.
    loadedProjectID = id
    if !createBranch, !availableBranches(checkedOut: checkedOut).contains(branch) {
      branch = availableBranches(checkedOut: checkedOut).first ?? ""
    }
  }

  /// Git refuses to check a branch out twice, so those are not offered.
  public func availableBranches(checkedOut: Set<String>) -> [String] {
    guard loadedProjectID != nil else { return [] }
    return localBranches.filter { !checkedOut.contains($0) }
  }

  /// The field and the picker share `branch`. Coming back restores what was
  /// typed, never what was picked, which would be a duplicate.
  public mutating func modeChanged(checkedOut: Set<String>) {
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
  public mutating func projectsChanged(to ids: [Project.ID]) {
    if let projectID, !ids.contains(projectID) { self.projectID = nil }
  }

  /// Whether the existing-branch picker gives way to a note that every local
  /// branch is checked out. Not while loading, when nothing is known yet.
  public func showsAllCheckedOutNote(checkedOut: Set<String>) -> Bool {
    guard let projectID, loadedProjectID == projectID else { return false }
    return availableBranches(checkedOut: checkedOut).isEmpty
  }

  public func canCreate(checkedOut: Set<String>) -> Bool {
    guard let projectID, loadedProjectID == projectID, hasCommits, !isCreating else {
      return false
    }
    return createBranch
      ? GitRefName.isValidBranch(branch)
      : availableBranches(checkedOut: checkedOut).contains(branch)
  }

  /// Whether what is typed is a name git would refuse, for the sheet to say
  /// so. An empty field is not yet wrong.
  public var branchNameIsRefused: Bool {
    guard createBranch else { return false }
    return !trimmedBranch.isEmpty && !GitRefName.isValidBranch(trimmedBranch)
  }

  /// The name as git would be handed it, the field's stray spaces dropped.
  var trimmedBranch: String {
    branch.trimmingCharacters(in: .whitespaces)
  }

  /// What the new branch starts from; `nil` lets git use HEAD. Never the
  /// empty string a cleared field would otherwise send.
  public var startPoint: String? {
    createBranch && !baseBranch.isEmpty ? baseBranch : nil
  }

  /// What the sheet says beside its spinner while a create runs, a hook
  /// taking a minute. `nil` is the tail: the refresh and the select.
  public static func progressText(for step: WorktreeCreationStep?) -> String {
    switch step {
    case .preCreateHook: t("step.pre-create-hook")
    case .addingWorktree: t("step.adding-worktree")
    case nil: t("step.creating-worktree")
    }
  }

  /// Picker labels. A folder name alone, unless another project shares it,
  /// when the path tells them apart.
  public static func labels(for projects: [Project]) -> [Project.ID: String] {
    var count: [String: Int] = [:]
    for project in projects { count[project.name, default: 0] += 1 }
    // Repair keeps identities unique; a repeat here must still not trap.
    return Dictionary(
      projects.map { project in
        let label =
          count[project.name] == 1
          ? project.name
          : "\(project.name)  (\(project.path.path.abbreviatingHomeDirectory()))"
        return (project.id, label)
      },
      uniquingKeysWith: { first, _ in first })
  }
}

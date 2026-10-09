import Foundation
import MultishellCore
import MultishellGitKit

/// What the New Worktree sheet decides: when Create is allowed, what git is
/// asked for, and what a project or mode switch does to the fields.
public struct NewWorktreeDraft: Equatable, Sendable {
  public var projectID: Project.ID?
  public var branch = ""
  public var createsBranch = true
  public var baseBranch = ""
  public internal(set) var localBranches: [String] = []
  public internal(set) var remoteBranches: [String] = []
  public internal(set) var hasCommits = true
  public var isCreating = false
  public var startsAgent = false
  public internal(set) var agentID = ""
  public var task = ""
  /// The agents the picker lists, installed or typed in settings.
  public internal(set) var offeredAgentIDs: [String] = []
  /// The project's own agent, taken again once the PATH scan offers it.
  var preferredAgentID: String?
  /// Whether `agentID` is the user's pick rather than a stand-in for an
  /// agent the PATH scan has not offered yet.
  var isAgentPicked = false
  /// What was typed in new-branch mode, kept across a visit to the
  /// existing-branch picker so coming back restores it.
  private var typedBranch = ""

  /// The project whose branches are on screen. Create waits for it to match
  /// the picker, so a stale load cannot enable it.
  private(set) var loadedProjectID: Project.ID?

  /// Whether what is typed is a name git would refuse, for the sheet to say
  /// so. An empty field is not yet wrong.
  public var branchNameIsRefused: Bool {
    guard createsBranch else { return false }
    return !trimmedBranch.isEmpty && !GitBranchName.isValid(trimmedBranch)
  }

  /// The name as git would be handed it, the field's stray spaces dropped.
  var trimmedBranch: String {
    branch.trimmingCharacters(in: .whitespaces)
  }

  /// What the new branch starts from; `nil` lets git use HEAD. Never the
  /// empty string a cleared field would otherwise send.
  public var startPoint: String? {
    createsBranch && !baseBranch.isEmpty ? baseBranch : nil
  }

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
    _ id: Project.ID,
    with read: NewWorktreeBranches,
    checkedOut: Set<String>,
  ) {
    guard id == projectID else { return }
    hasCommits = read.hasCommits
    localBranches = read.localBranches
    remoteBranches = read.remoteBranches
    baseBranch = read.currentBranch
    // Recorded before the fix-up below, which reads the available branches
    // and sees none for a project not yet marked loaded.
    loadedProjectID = id
    if !createsBranch, !availableBranches(checkedOut: checkedOut).contains(branch) {
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
  public mutating func fitBranchToMode(checkedOut: Set<String>) {
    if createsBranch {
      branch = typedBranch
    } else {
      typedBranch = branch
      let available = availableBranches(checkedOut: checkedOut)
      if !available.contains(branch) { branch = available.first ?? "" }
    }
  }

  /// A project removed from the sidebar while the sheet is up goes back to
  /// the placeholder rather than a selection nothing in the list matches.
  public mutating func forgetProject(unlessIn ids: [Project.ID]) {
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
    return createsBranch
      ? GitBranchName.isValid(branch)
      : availableBranches(checkedOut: checkedOut).contains(branch)
  }
}

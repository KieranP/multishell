import Foundation
import MultishellCore
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelProjectsTests {
  @Test func addingARepositoryDiscoversItsMainWorktreeAndArmsTheWatcher() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }

    #expect(h.model.workspace.projects.count == 1)
    #expect(h.model.presentedError == nil)
    let worktrees = h.model.workspace.worktrees(of: h.project.id)
    #expect(worktrees.map(\.branch) == ["main"])
    #expect(worktrees[0].isPrimary)
    #expect(h.watcher.watched.map(\.lastPathComponent) == [".git"])
  }

  @Test func addingASubdirectoryIsTheSameProject() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let sources = h.project.path.appendingPathComponent("Sources", isDirectory: true)
    try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)

    await h.model.addProject(at: sources)

    #expect(h.model.workspace.projects.count == 1, "identity is the main worktree's path")
  }

  @Test func addingSomethingThatIsNotARepositoryIsRefused() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }

    await h.model.addProject(at: h.root)

    #expect(h.model.workspace.projects.count == 1)
    #expect(h.model.presentedError?.title == "Not a git repository")
  }

  @Test func aBareCloneIsAddedAsAProjectWithItsBareEntryFirst() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let bare = h.root.appendingPathComponent("repo.git", isDirectory: true)
    _ = try await h.git.run(["clone", "-q", "--bare", h.project.path.path, bare.path], in: h.root)
    let checkout = h.root.appendingPathComponent("checkout", isDirectory: true)
    _ = try await h.git.run(["worktree", "add", "-q", checkout.path, "main"], in: bare)

    await h.model.addProject(at: checkout)

    #expect(h.model.presentedError == nil)
    let project = try #require(h.model.workspace.project(bare.standardizedFileURL.path))
    #expect(project.name == "repo")
    let worktrees = h.model.workspace.worktrees(of: project.id)
    #expect(worktrees.map(\.isBare) == [true, false])
    #expect(worktrees[0].isPrimary && worktrees[1].branch == "main")
    await h.model.refreshStatuses()
    #expect(h.model.statuses[worktrees[0].id] == nil, "no status poll for the bare entry")
    #expect(h.model.statuses[worktrees[1].id] != nil)
  }
  /// Removing the project covers the hooks in it. The `sleep 30` is what
  /// proves the signal, the setup task not being awaitable.
  @Test func removingAProjectEndsAHookStillRunningInItsWorktrees() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.updateSettings(ProjectSettings(postCreateHook: "sleep 30"), for: h.project)

    // `h.project` re-read each time: the create takes its hooks off the
    // value it is handed, so a copy from before the settings write has none.
    await h.model.createWorktree(branch: "setup", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "setup"))
    #expect(h.model.worktreeOperations[created.id]?.isRunning == true)

    // Taken before the removal, which is what clears the entry.
    let setup = h.model.stageHandles.setup(of: created.id)
    h.model.removeProject(h.project)
    await setup?.value

    #expect(h.model.workspace.projects.isEmpty)
    #expect(h.model.worktreeOperations[created.id] == nil)
    #expect(h.model.stageHandles.setup(of: created.id) == nil)
    #expect(h.model.presentedError == nil, "the user asked for this, so there is nothing to report")
    #expect(
      h.model.workspace.tabs(in: created.id).isEmpty,
      "and no first tab opens in a worktree whose project has gone")
  }
  /// Fields that are meant to still name a departed project, each for a
  /// reason the field's own comment gives.
  private static let exempt: Set<String> = [
    // Pruned by the next `refreshStatuses` against the workspace, which is
    // cheaper than walking every worktree on a removal.
    "_statuses",
    // A coalesced refresh that finds its worktree gone and does nothing.
    "pendingStatusRefreshes",
  ]

  /// Walked by reflection rather than field by field, so a path-keyed cache added later is
  /// caught without anyone remembering to extend this test.
  @Test func removingAProjectLeavesNoRuntimeTraceOfIt() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let project = h.project

    // A `.multishell.json` and a second worktree give the shared-settings cache, the merge scan
    // and the record check something to hold before the project goes.
    try #"{"branchPrefix": "team/"}"#.write(
      to: SharedProjectSettings.file(in: project.path), atomically: true, encoding: .utf8)
    await h.model.createWorktree(
      branch: "second", basedOn: nil, createBranch: true, in: project)
    await h.model.refreshAll()
    let worktrees = h.model.workspace.worktrees(of: project.id)
    _ = h.model.select(worktrees[0])
    // The references a window and a row hold, which no refresh will come
    // back to clear once the project has left.
    h.model.beginRenamingWorktree(worktrees[0])
    h.model.settingsProjectID = project.id
    // The dialogs a second scene can leave standing over a removal.
    h.model.requestNewWorktree(in: project)
    await h.model.requestWorktreeRemoval(of: worktrees[1])?.value

    let paths = Set(
      [project.id] + h.model.workspace.worktrees(of: project.id).map(\.id))
    #expect(paths.count >= 2, "the project and at least one worktree of its own")
    #expect(
      h.model.workspace.project(project.id)?.sharedSettings.hasBeenRead == true,
      "the file was read, so the project holds something")

    h.model.removeProject(project)

    for (field, value) in Self.traces(in: h.model, of: paths) {
      #expect(Bool(false), "\(field) still names \(value) after its project was removed")
    }
  }

  private static func traces(
    in model: AppModel<FakeSurface>, of paths: Set<String>
  ) -> [(field: String, value: String)] {
    var found: [(field: String, value: String)] = []
    for child in Mirror(reflecting: model).children {
      guard let label = child.label, !exempt.contains(label) else { continue }
      for hit in strings(in: child.value) where paths.contains(hit) {
        found.append((label, hit))
      }
    }
    return found
  }

  /// Classes are skipped, keeping out the store, reconciler and engine, which answer to the
  /// workspace. The depth bound only stops endless nesting; a cache buried deeper goes unchecked.
  private static func strings(in value: Any, depth: Int = 0) -> [String] {
    guard depth < 12 else { return [] }
    if let text = value as? String { return [text] }
    if let keyed = value as? [String: Any] {
      return Array(keyed.keys) + keyed.values.flatMap { strings(in: $0, depth: depth + 1) }
    }
    if let set = value as? Set<String> { return Array(set) }
    if let list = value as? [String] { return list }
    let mirror = Mirror(reflecting: value)
    switch mirror.displayStyle {
    case .struct, .enum, .optional, .tuple, .collection, .set, .dictionary:
      return mirror.children.flatMap { strings(in: $0.value, depth: depth + 1) }
    default:
      return []
    }
  }

  @Test func removingAProjectAsksFirstInTheWindowThatAsked() throws {
    let h = Harness()
    h.model.select(h.main)
    #expect(h.model.liveTerminalCount == 1)

    h.model.requestProjectRemoval(h.project, from: .settings)

    let pending = try #require(h.model.pendingProjectRemoval)
    #expect(pending.project.id == h.project.id)
    #expect(pending.source == .settings)
    #expect(h.model.workspace.projects.count == 1, "nothing removed until confirmed")
    #expect(
      h.model.projectRemovalMessage(for: h.project).contains("1 open terminal will be closed"))

    h.model.pendingProjectRemoval = nil
    h.model.removeProject(h.project)
    #expect(h.model.workspace.projects.isEmpty)
    #expect(h.model.liveTerminalCount == 0)
  }

  @Test func selectedProjectFollowsSelectionOrTheOnlyProject() {
    let h = Harness()
    #expect(h.model.selectedProject?.id == h.project.id, "one project, nothing selected")
    h.store.addProject(at: URL(fileURLWithPath: "/other"))
    #expect(h.model.selectedProject == nil, "two projects, nothing selected")
    h.model.select(h.feature)
    #expect(h.model.selectedProject?.id == h.project.id)
  }

  @Test func aCancelledDirectoryPickerAddsNothing() async {
    let h = Harness()
    h.platform.directoryToChoose = nil
    await h.model.chooseProject()
    #expect(h.model.workspace.projects.count == 1)
  }
}

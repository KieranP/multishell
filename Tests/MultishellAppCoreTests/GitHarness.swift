import Foundation
import MultishellCore
import Observation
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

/// The model on real git in a throwaway repository, with a fake engine and
/// watcher: the sidebar flows from a click to the shells and the repository.
@MainActor
struct GitHarness {
  let root: URL
  let git: GitRunner
  let model: AppModel<FakeSurface>
  let store: WorkspaceStore
  let engine = FakeEngine()
  let watcher = FakeWatcher()
  let platform = FakePlatform()

  init() async throws {
    git = try TestGit.build()
    root = Scratch.path("appgit")
    let repository = root.appendingPathComponent("demo", isDirectory: true)
    try await TestRepository.initialise(at: repository, using: git)
    try await TestRepository.commitInitial(in: repository, using: git)

    store = WorkspaceStore(
      snapshot: WorkspaceSnapshot(fileURL: root.appendingPathComponent("state.json")))
    model = AppModel(
      store: store,
      host: self.engine,
      worktrees: WorktreeCoordinator(
        service: WorktreeService(git: git, settlesNewIndex: false)),
      watcher: watcher, platform: platform)
    model.statusReads.pace = .unpaced
    await model.addProject(at: repository)
  }

  /// Waits for the removal that `requestRemoval` or a dialog started, up to
  /// a few seconds, by watching the operation entry.
  func awaitOperationEnd(on id: Worktree.ID) async {
    for _ in 0..<200 where model.worktreeOperations[id]?.isRunning == true {
      try? await Task.sleep(for: .milliseconds(50))
    }
  }

  var project: Project { model.workspace.projects[0] }

  /// `link/key` in the repository, where `link` leads out of it: a list that
  /// passes the spelling check and is refused against the disk.
  func divertARepositoryPathWithASymlink() throws {
    let manager = FileManager.default
    let outside = root.appendingPathComponent("outside", isDirectory: true)
    try manager.createDirectory(at: outside, withIntermediateDirectories: true)
    try "TOP SECRET".write(
      to: outside.appendingPathComponent("key"), atomically: true, encoding: .utf8)
    try manager.createSymbolicLink(
      at: project.path.appendingPathComponent("link"), withDestinationURL: outside)
  }

  func shipSharedSettings(_ json: String) throws {
    try json.write(
      to: SharedProjectSettings.file(in: project.path), atomically: true, encoding: .utf8)
  }

  /// A second model on the same store, with `body` as a shell script standing
  /// in for git.
  func modelOnFakeGit(_ body: String) throws -> AppModel<FakeSurface> {
    let script = root.appendingPathComponent("fake-git-\(UUID().uuidString)")
    try Scratch.script(
      """
      SCRATCH="\(root.path)"
      echo "$*" >> "$SCRATCH/calls"
      \(body)
      """, at: script)
    let model = AppModel(
      store: store,
      host: self.engine,
      worktrees: WorktreeCoordinator(
        service: WorktreeService(git: try GitRunner(executable: script), settlesNewIndex: false)),
      watcher: watcher)
    model.statusReads.pace = .unpaced
    model.presentedError = nil
    return model
  }

  func gitCalls() -> [String] {
    (try? String(contentsOf: root.appendingPathComponent("calls"), encoding: .utf8))?
      .split(whereSeparator: \.isNewline).map(String.init) ?? []
  }

  func worktree(onBranch branch: String) -> Worktree? {
    model.workspace.worktrees(of: project.id).first { $0.branch == branch }
  }

  /// The autosave debounce would otherwise land 300 ms later and re-make
  /// the directory around its state file.
  func tearDown() {
    model.saveNow()
    Scratch.remove(root)
  }
}

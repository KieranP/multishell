import Foundation
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
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

  var project: Project { model.workspace.projects[0] }

  init() async throws {
    git = try TestGit.runner()
    root = Scratch.path("appgit")
    let repository = root.appendingPathComponent("demo", isDirectory: true)
    try await TestRepository.initialise(at: repository, withFirstCommit: true, using: git)

    store = WorkspaceStore(
      file: StateFile(fileURL: root.appendingPathComponent("state.json"))
    )
    model = AppModel(
      store: store,
      host: self.engine,
      coordinator: TestGit.coordinator(runner: git),
      watcher: watcher,
      platform: platform,
    )
    model.statusReadLog.pace = .unpaced
    await model.addProject(at: repository)
  }

  /// Waits for the removal that `requestWorktreeRemoval` or a dialog started, up to
  /// ten seconds, by watching the operation entry.
  func awaitOperationEnd(on id: Worktree.ID) async {
    try? await waitUntil({ model.worktreeOperations[id]?.isRunning != true }, seconds: 10)
  }

  /// `link/key` in the repository, where `link` leads out of it: a list that
  /// passes the spelling check and is refused against the disk.
  func divertARepositoryPathWithASymlink() throws {
    let manager = FileManager.default
    let outside = root.appendingPathComponent("outside", isDirectory: true)
    try manager.createDirectory(at: outside, withIntermediateDirectories: true)
    try "TOP SECRET".write(
      to: outside.appendingPathComponent("key"),
      atomically: true,
      encoding: .utf8,
    )
    try manager.createSymbolicLink(
      at: project.path.appendingPathComponent("link"),
      withDestinationURL: outside,
    )
  }

  @discardableResult
  func writeSharedSettings(_ json: String) throws -> URL {
    let file = SharedProjectSettings.file(in: project.path)
    try json.write(to: file, atomically: true, encoding: .utf8)
    return file
  }

  /// A second model on the same store, with `body` as a shell script standing
  /// in for git.
  func modelOnFakeGit(_ body: String) throws -> AppModel<FakeSurface> {
    let fake = try FakeGit.make(body, in: root, loggingCalls: true)
    let model = AppModel(
      store: store,
      host: self.engine,
      coordinator: fake.coordinator,
      watcher: watcher,
    )
    model.statusReadLog.pace = .unpaced
    model.presentedError = nil
    return model
  }

  /// Selects the first worktree, which is where the trust question is asked,
  /// and answers it.
  func answerTrust(_ isTrusted: Bool) throws {
    model.select(model.workspace.worktrees(of: project.id)[0])
    model.answerSharedSettingsTrust(
      try #require(model.pendingSharedSettingsTrust),
      isTrusted: isTrusted,
    )
  }

  /// An untracked file, which is what the status badge counts.
  func dirty(_ worktree: Worktree) throws {
    try "x".write(
      to: worktree.path.appendingPathComponent("dirty.txt"),
      atomically: true,
      encoding: .utf8,
    )
  }

  /// Every queued status refresh is cancelled and every badge cleared, so a
  /// test sees only the reads it causes. The pace log is left alone.
  func clearStatuses() {
    for pending in model.pendingStatusRefreshes.values { pending.cancel() }
    model.pendingStatusRefreshes = [:]
    model.statuses = [:]
  }

  /// A model on fake git whose `git status` takes 0.6 s, read at the standard pace.
  func modelWithSlowStatus() throws -> AppModel<FakeSurface> {
    let fake = try modelOnFakeGit("case \"$*\" in *status*) sleep 0.6;; esac; exit 0")
    fake.statusReadLog.pace = .standard
    return fake
  }

  /// A model on fake git whose first `git status` waits for `gate` to exist.
  func modelWithFirstStatusHeld(until gate: URL) throws -> AppModel<FakeSurface> {
    try modelOnFakeGit(
      """
      case "$*" in
        *status*)
          if [ ! -f "$SCRATCH/first" ]; then
            touch "$SCRATCH/first"
            while [ ! -f "\(gate.path)" ]; do sleep 0.02; done
          fi
          printf '## main\\n' ;;
      esac
      """
    )
  }

  /// A model on fake git whose every `git status` waits for `gate`, or for the
  /// harness to be torn down, then answers on `branch`.
  func modelWithStatusHeld(
    until gate: URL,
    answering branch: String,
  ) throws
    -> AppModel<FakeSurface>
  {
    try modelOnFakeGit(
      """
      case "$*" in
        *status*) while [ ! -f "\(gate.path)" ] && [ -d "\(root.path)" ]; do sleep 0.02; done
          printf '## \(branch)\\n' ;;
      esac
      """
    )
  }

  /// `git worktree add -b` run by hand, as the user would outside the app.
  func addOutsideTheApp(_ branch: String, at directory: URL) async throws {
    try await TestRepository.addWorktree(
      onNewBranch: branch,
      at: directory,
      in: project.path,
      using: git,
    )
  }

  /// `git worktree remove --force` run by hand, as the user would outside the app.
  func removeOutsideTheApp(_ directory: URL) async throws {
    _ = try await git.run(["worktree", "remove", "--force", directory.path], in: project.path)
  }

  func branches() async throws -> [String] {
    try await TestRepository.branches(in: project.path, using: git)
  }

  func gitCalls() -> [String] {
    FakeGit.calls(in: root)
  }

  func statusRunCount() -> Int {
    gitCalls().filter { $0.contains("status") }.count
  }

  func gitCallCount(startingWith prefix: String) -> Int {
    gitCalls().filter { $0.hasPrefix(prefix) }.count
  }

  /// A second repository with one commit, added as a project of its own.
  func addSecondProject() async throws -> Project {
    let second = root.appendingPathComponent("other", isDirectory: true)
    try await TestRepository.initialise(at: second, withFirstCommit: true, using: git)
    await model.addProject(at: second)
    return try #require(model.workspace.projects.first { $0.id != project.id })
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

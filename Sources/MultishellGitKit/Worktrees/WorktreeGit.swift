import Foundation
import MultishellCore
import MultishellProcess

/// The git side of worktree management. Knows nothing about hooks or settings.
/// Its reads are public, the app asking them through the coordinator's `git`.
public struct WorktreeGit: Sendable {
  /// Internal rather than private so the merge reads, which are their own
  /// file, can run through the same runner.
  let runner: GitRunner
  /// Shared by the copies of this value, and by those a later git makes.
  let shared: SharedGitReads

  /// Off only in the suites, whose hundreds of creates would each wait a second.
  let settlesNewIndex: Bool

  init(
    runner: GitRunner, settlesNewIndex: Bool = true, shared: SharedGitReads = SharedGitReads()
  ) {
    self.runner = runner
    self.settlesNewIndex = settlesNewIndex
    self.shared = shared
  }

  init(searchPath: String? = nil) throws {
    self.init(runner: try GitRunner(searchPath: searchPath))
  }

  /// `--git-dir`, not `--is-inside-work-tree`, which prints `false` for a
  /// bare repository: a common layout for people who live in worktrees.
  public func isRepository(_ url: URL) async -> Bool {
    await runner.succeeds(["rev-parse", "--git-dir"], in: url)
  }

  /// False for a freshly initialised repository. `HEAD` is unborn there, so
  /// nothing can be branched from it until the first commit.
  public func hasCommits(_ project: Project) async -> Bool {
    await runner.succeeds(["rev-parse", "--verify", "--quiet", "HEAD"], in: project.path)
  }

  /// Every repository has at least its main worktree, so an empty list is
  /// git failing quietly; taken as a result it drops every tab.
  public func list(_ project: Project) async throws -> [Worktree] {
    let worktrees = try await listing(in: project.path, projectID: project.id)
    guard !worktrees.isEmpty else {
      throw ProcessFailure(
        executable: "git", arguments: ["worktree", "list"], status: 0,
        message: "git listed no worktrees for \(project.path.path)")
    }
    return worktrees.map(Self.datedByDirectory).map(Self.markedIfUnfinished)
  }

  /// A lock older than this is an add that died mid-checkout, git's own
  /// cleanup running only on a signal it can catch; see worktrees.md.
  private static let abandonedAddAge: TimeInterval = 10 * 60

  /// git's `initializing` is in the user's language, so a lock from before
  /// `gitdir` over files with no index yet counts too; see worktrees.md.
  private static func markedIfUnfinished(_ worktree: Worktree) -> Worktree {
    guard worktree.isLocked else { return worktree }
    let admin = adminDirectory(named: worktree.path)
    let lockedAt =
      admin.flatMap { modified($0.appendingPathComponent("locked")) } ?? worktree.createdAt
    if !worktree.isInitializing {
      guard let admin,
        !FileManager.default.fileExists(atPath: admin.appendingPathComponent("index").path),
        let lockedAt, let linkedAt = modified(admin.appendingPathComponent("gitdir")),
        lockedAt <= linkedAt, hasCheckedOutFiles(worktree.path)
      else { return worktree }
    }
    var marked = worktree
    marked.isInitializing = lockedAt.map { -$0.timeIntervalSinceNow < abandonedAddAge } ?? false
    return marked
  }

  /// `add --no-checkout` writes nothing beside `.git`, and one made with
  /// `--lock` looks otherwise like an add still checking out.
  private static func hasCheckedOutFiles(_ checkout: URL) -> Bool {
    let entries = (try? FileManager.default.contentsOfDirectory(atPath: checkout.path)) ?? []
    return entries.contains { $0 != ".git" }
  }

  private static func modified(_ file: URL) -> Date? {
    try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
  }

  /// `-z` came in git 2.36, and an older one refuses the switch with 129; its
  /// newline form is read instead, at the cost of a path holding a newline.
  private func listing(in directory: URL, projectID: Project.ID) async throws -> [Worktree] {
    do {
      let output = try await runner.run(["worktree", "list", "--porcelain", "-z"], in: directory)
      return WorktreeListParser.parse(output, projectID: projectID)
    } catch let failure as ProcessFailure where failure.status == 129 {
      let output = try await runner.run(["worktree", "list", "--porcelain"], in: directory)
      return WorktreeListParser.parse(output, projectID: projectID, separator: "\n")
    }
  }

  /// git records no creation time, so the sidebar sorts by the directory's
  /// birth time, stamped on here to keep the parser off the filesystem.
  private static func datedByDirectory(_ worktree: Worktree) -> Worktree {
    var dated = worktree
    dated.createdAt = try? worktree.path.resourceValues(forKeys: [.creationDateKey]).creationDate
    return dated
  }

  /// The main worktree of the repository `url` is in, from anywhere in it,
  /// which identifies a project so a subdirectory does not become a second.
  public func mainWorktree(containing url: URL) async throws -> URL {
    guard let main = try await listing(in: url, projectID: "").first else {
      throw ProcessFailure(
        executable: "git", arguments: ["worktree", "list"], status: 0,
        message: "no worktree listed for \(url.path)")
    }
    return main.path
  }

  /// The `.git` directory every worktree shares, where git records them. Stable
  /// for a project's life, so the watcher and the records check need no spawn.
  public func commonGitDirectory(_ project: Project) async throws -> URL {
    let output = try await runner.run(
      ["rev-parse", Self.absolutePathFormat, "--git-common-dir"], in: project.path)
    guard let common = Self.absolutePaths(in: output, from: project.path).first else {
      throw ProcessFailure(
        executable: "git", arguments: ["rev-parse", "--git-common-dir"], status: 0,
        message: "git named no common directory for \(project.path.path)")
    }
    return common
  }

  static let absolutePathFormat = "--path-format=absolute"

  /// The flag came in git 2.31. An older git echoes it back as a flag it does
  /// not know and answers relative to where it ran, so that is resolved here.
  static func absolutePaths(in output: String, from directory: URL) -> [URL] {
    var lines = output.split(whereSeparator: \.isNewline).map(String.init)
    if lines.first == absolutePathFormat { lines.removeFirst() }
    return lines.map { directoryURL($0, relativeTo: directory) }
  }

  /// A directory as git wrote it, absolute or relative to `base`.
  static func directoryURL(_ written: String, relativeTo base: URL) -> URL {
    written.hasPrefix("/")
      ? URL(fileURLWithPath: written, isDirectory: true)
      : base.appendingPathComponent(written, isDirectory: true).standardizedFileURL
  }

  /// `git worktree add [-b <branch>] <path> <start point>`; `createBranch: false`
  /// checks out an existing branch. No timeout, only `stopper`; see worktrees.md.
  func add(
    branch: String,
    at path: URL,
    basedOn startPoint: String? = nil,
    createBranch: Bool = true,
    in project: Project,
    stopper: ProcessStopper? = nil
  ) async throws {
    var arguments = ["worktree", "add"]
    if createBranch { arguments += ["-b", branch] }
    arguments.append(path.path)
    arguments.append(createBranch ? (startPoint ?? "HEAD") : branch)
    _ = try await runner.run(arguments, in: project.path, stopper: stopper)
  }

  /// Where a linked checkout's `.git` file says its record is, relative or absolute.
  static func adminDirectory(named checkout: URL) -> URL? {
    guard
      let gitFile = try? String(
        contentsOf: checkout.appendingPathComponent(".git"), encoding: .utf8),
      let line = gitFile.split(separator: "\n").first, line.hasPrefix("gitdir: ")
    else { return nil }
    return directoryURL(String(line.dropFirst("gitdir: ".count)), relativeTo: checkout)
  }

  /// An answer that proves nothing, unreadable or empty, counts as listed:
  /// the caller deletes the branch next. See Docs/design/worktrees.md.
  func isListed(_ path: URL, in project: Project) async -> Bool {
    guard let listed = try? await listing(in: project.path, projectID: project.id),
      !listed.isEmpty
    else { return true }
    let wanted = Self.realPath(of: path)
    return listed.contains { Self.realPath(of: $0.path) == wanted }
  }

  /// A dangling link kept by name, as git lists a worktree below one.
  static func realPath(of url: URL) -> String {
    (url.resolvedAsFarAsItExists(keepingDanglingLinks: true) ?? url.standardizedFileURL).path
  }

  /// Written once, a second after the checkout: git trusts no stat data from the
  /// second an index was written in; see Docs/design/worktrees.md.
  func refreshIndex(of worktree: URL, stopper: ProcessStopper? = nil) async {
    guard settlesNewIndex else { return }
    let now = Date().timeIntervalSince1970
    let settled = ContinuousClock.now + .seconds(now.rounded(.down) + 1.01 - now)
    // In slices, so the sheet's Cancel ends the wait rather than sitting it out.
    while stopper?.isStopped != true, ContinuousClock.now < settled {
      try? await Task.sleep(for: min(.milliseconds(50), settled - .now))
    }
    guard stopper?.isStopped != true else { return }
    _ = await runner.output(["update-index", "-q", "--refresh"], in: worktree)
  }

}

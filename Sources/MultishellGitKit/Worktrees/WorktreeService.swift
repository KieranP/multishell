import Foundation
import MultishellCore
import MultishellProcess

/// The git side of worktree management. Knows nothing about hooks or settings.
struct WorktreeService: Sendable {
  /// Internal rather than private so the merge reads, which are their own
  /// file, can run through the same runner.
  let git: GitRunner
  /// Shared by the copies of this value, so every poll reuses the counts.
  let untrackedMemo: UntrackedLineMemo
  /// One width for every project's merge reads, the model running several
  /// projects' at once; see Docs/design/merged-branch.md.
  let mergeSlots: GitSlots

  /// Off only in the suites, whose hundreds of creates would each wait a second.
  let settlesNewIndex: Bool

  init(git: GitRunner) {
    self.init(git: git, settlesNewIndex: true)
  }

  init(
    git: GitRunner, settlesNewIndex: Bool,
    untrackedMemo: UntrackedLineMemo = UntrackedLineMemo(),
    mergeSlots: GitSlots = GitSlots(width: WorktreeCoordinator.maxConcurrentStatuses)
  ) {
    self.git = git
    self.settlesNewIndex = settlesNewIndex
    self.untrackedMemo = untrackedMemo
    self.mergeSlots = mergeSlots
  }

  /// On another git, keeping the counts and the merge width: reads still in
  /// flight on this one hold slots the new one must count.
  func running(_ git: GitRunner) -> WorktreeService {
    WorktreeService(
      git: git, settlesNewIndex: settlesNewIndex, untrackedMemo: untrackedMemo,
      mergeSlots: mergeSlots)
  }

  init(path: String? = nil) throws {
    self.init(
      git: try GitRunner(executable: ExecutableLookup.find("git", path: path), path: path))
  }

  /// `--git-dir`, not `--is-inside-work-tree`, which prints `false` for a
  /// bare repository: a common layout for people who live in worktrees.
  func isRepository(_ url: URL) async -> Bool {
    await git.succeeds(["rev-parse", "--git-dir"], in: url)
  }

  /// False for a freshly initialised repository. `HEAD` is unborn there, so
  /// nothing can be branched from it until the first commit.
  func hasCommits(_ project: Project) async -> Bool {
    await git.succeeds(["rev-parse", "--verify", "--quiet", "HEAD"], in: project.path)
  }

  /// Every repository has at least its main worktree, so an empty list is
  /// git failing quietly; taken as a result it drops every tab.
  func list(_ project: Project) async throws -> [Worktree] {
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
      let output = try await git.run(["worktree", "list", "--porcelain", "-z"], in: directory)
      return WorktreeListParser.parse(output, projectID: projectID)
    } catch let failure as ProcessFailure where failure.status == 129 {
      let output = try await git.run(["worktree", "list", "--porcelain"], in: directory)
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

  /// The main worktree of the repository `url` is in, wherever in it `url`
  /// is: `git worktree list` puts that one first from anywhere.
  func mainWorktree(containing url: URL) async throws -> URL {
    guard let main = try await listing(in: url, projectID: "").first else {
      throw ProcessFailure(
        executable: "git", arguments: ["worktree", "list"], status: 0,
        message: "no worktree listed for \(url.path)")
    }
    return main.path
  }

  /// `--no-optional-locks`: a plain `git status` takes `index.lock`, and this
  /// polls, so a `git commit` typed at the wrong moment would fail.
  func status(
    of worktree: Worktree, counting indicator: GitStatusIndicator = .default
  )
    async throws -> WorktreeStatus
  {
    let output = try await git.run(
      ["--no-optional-locks", "status", "--porcelain=v1", "--branch"], in: worktree.path)
    var status = WorktreeStatusParser.parse(output)
    guard status.isDirty else { return status }
    let stat = await lineCounts(
      in: worktree.path, counting: indicator, untracked: status.untracked)
    status.insertions = stat.insertions
    status.deletions = stat.deletions
    status.unscoredFiles = stat.unscored
    return status
  }

  /// `--cached` is the index alone, and the fallback wherever the diff
  /// against HEAD fails, which an unborn HEAD does; see worktrees.md.
  private func lineCounts(
    in path: URL, counting indicator: GitStatusIndicator, untracked: Int
  ) async -> (
    insertions: Int, deletions: Int, unscored: Int
  ) {
    // `--diff-filter=u` drops unmerged paths, which print `0 0` from
    // `--cached` and read as a file with nothing to count.
    let numstat = ["--no-optional-locks", "diff", "--numstat", "--diff-filter=u"]
    var stat = (insertions: 0, deletions: 0, unscored: 0)
    if indicator == .stagedAndUnstaged,
      let output = await git.output(numstat + ["HEAD"], in: path)
    {
      stat = DiffStatParser.parse(output)
    } else if let cached = await git.output(numstat + ["--cached"], in: path) {
      stat = DiffStatParser.parse(cached)
    }
    guard indicator == .stagedAndUnstaged, untracked > 0 else { return stat }
    let loose = await untrackedCounts(in: path)
    stat.insertions += loose.lines
    stat.unscored += loose.unscored
    return stat
  }

  /// The reads block, on a dead mount until it times out. Detached keeps them off
  /// the main actor but not off the cooperative pool; see worktrees.md.
  private func untrackedCounts(in path: URL) async -> (lines: Int, unscored: Int) {
    guard
      let output = await git.output(
        ["--no-optional-locks", "ls-files", "--others", "--exclude-standard", "-z"], in: path)
    else { return (0, 0) }
    let paths = UntrackedLineCounter.paths(from: output)
    guard !paths.isEmpty else { return (0, 0) }
    let memo = untrackedMemo
    return await Task.detached(priority: .utility) {
      UntrackedLineCounter.count(paths: paths, in: path, memo: memo)
    }.value
  }

  /// Every branch with its tip, upstream and date, in one process, the date
  /// atom retried separately. `nil` is a failed read, not no branches.
  func branchRefs(_ project: Project) async -> [BranchRef]? {
    if let output = await git.output(Self.refQuery(withDates: true), in: project.path) {
      return BranchRefParser.parse(output)
    }
    guard let output = await git.output(Self.refQuery(withDates: false), in: project.path) else {
      return nil
    }
    return BranchRefParser.parse(output)
  }

  private static func refQuery(withDates: Bool) -> [String] {
    var format = [
      "%(refname)", "%(objectname)", "%(upstream)", "%(upstream:track)", "%(symref)",
    ]
    if withDates { format.append("%(committerdate:unix)") }
    return [
      "for-each-ref", "--format=" + format.joined(separator: "%09"), "refs/heads", "refs/remotes",
    ]
  }

  /// `git fetch --prune`, on the user's click only: the one git call here
  /// that talks to a network. `GIT_TERMINAL_PROMPT=0`, and a timeout.
  func fetch(_ project: Project, timeout: Duration = .seconds(120)) async throws {
    _ = try await git.run(
      ["fetch", "--prune", "--quiet"], in: project.path,
      environment: ["GIT_TERMINAL_PROMPT": "0"], timeout: timeout)
  }

  func localBranches(_ project: Project) async throws -> [String] {
    let output = try await git.run(
      ["for-each-ref", "--format=%(refname:short)", "refs/heads"],
      in: project.path
    )
    return output.split(whereSeparator: \.isNewline)
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
  }

  /// Remote branches with the symbolic `origin/HEAD` dropped. Full ref names,
  /// `%(refname:short)` abbreviating that one to `origin`.
  func remoteBranches(_ project: Project) async throws -> [String] {
    let output = try await git.run(
      ["for-each-ref", "--format=%(refname)", "refs/remotes"],
      in: project.path
    )
    let prefix = BranchRef.remotePrefix
    return output.split(whereSeparator: \.isNewline)
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { $0.hasPrefix(prefix) && !$0.hasSuffix("/HEAD") }
      .map { String($0.dropFirst(prefix.count)) }
  }

  /// The `.git` directory shared by every worktree of the repository; where
  /// git records worktrees, so where to watch for them.
  func commonGitDirectory(_ project: Project) async throws -> URL {
    let output = try await git.run(
      ["rev-parse", Self.absolutePathFormat, "--git-common-dir"], in: project.path)
    guard let common = Self.absolutePaths(in: output, from: project.path).first else {
      throw ProcessFailure(
        executable: "git", arguments: ["rev-parse", "--git-common-dir"], status: 0,
        message: "git named no common directory for \(project.path.path)")
    }
    return common
  }

  private static let absolutePathFormat = "--path-format=absolute"

  /// The flag came in git 2.31. An older git echoes it back as a flag it does
  /// not know and answers relative to where it ran, so that is resolved here.
  private static func absolutePaths(in output: String, from directory: URL) -> [URL] {
    var lines = output.split(whereSeparator: \.isNewline).map(String.init)
    if lines.first == absolutePathFormat { lines.removeFirst() }
    return lines.map { line in
      line.hasPrefix("/")
        ? URL(fileURLWithPath: line, isDirectory: true)
        : directory.appendingPathComponent(line, isDirectory: true).standardizedFileURL
    }
  }

  func currentBranch(_ project: Project) async throws -> String {
    try await git.run(["rev-parse", "--abbrev-ref", "HEAD"], in: project.path)
      .trimmingCharacters(in: .whitespacesAndNewlines)
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
    _ = try await git.run(arguments, in: project.path, stopper: stopper)
  }

  /// Forgets one record whose directory has already gone, a lock included.
  /// Only after the trash: with the directory there it would unlink it.
  func forget(_ worktree: Worktree, in project: Project) async throws {
    do {
      // One --force for a tree git cannot inspect, the second for a lock,
      // which stays on the record until this moment rather than being unlocked.
      _ = try await git.run(
        ["worktree", "remove", "--force", "--force", worktree.path.path], in: project.path)
    } catch let refusal {
      // A record git cannot match to the path; see Docs/design/worktrees.md.
      do {
        _ = try await git.run(["worktree", "prune"], in: project.path)
      } catch {
        throw WorktreeForgetFailure(path: worktree.path, underlying: error)
      }
      // prune exits 0 whether or not this record was one it took, and the
      // caller deletes the branch on a success; see Docs/design/worktrees.md.
      guard await !isListed(worktree.path, in: project) else {
        throw WorktreeForgetFailure(path: worktree.path, underlying: refusal)
      }
    }
  }

  /// Whether the directory at the record's path is still that worktree's
  /// checkout. Throws where the project's own git cannot answer.
  func isCheckout(of worktree: Worktree, in project: Project) async throws -> Bool {
    let common = try await commonGitDirectory(project)
    guard
      let output = await git.output(
        ["rev-parse", Self.absolutePathFormat, "--show-toplevel", "--git-common-dir"],
        in: worktree.path)
    else {
      // git refusing the directory, over ownership or a timeout, proves nothing
      // about whose it is; the `.git` file git wrote there does.
      guard let admin = Self.adminDirectory(named: worktree.path) else { return false }
      return Self.samePath(
        admin.deletingLastPathComponent(), common.appendingPathComponent("worktrees"))
    }
    let lines = Self.absolutePaths(in: output, from: worktree.path)
    // The top level too: a plain directory inside the main checkout answers
    // with the main repository's common directory.
    return lines.count == 2 && Self.samePath(lines[0], worktree.path)
      && Self.samePath(lines[1], common)
  }

  /// Where a linked checkout's `.git` file says its record is, relative or absolute.
  private static func adminDirectory(named checkout: URL) -> URL? {
    guard
      let gitFile = try? String(
        contentsOf: checkout.appendingPathComponent(".git"), encoding: .utf8),
      let line = gitFile.split(separator: "\n").first, line.hasPrefix("gitdir: ")
    else { return nil }
    let target = String(line.dropFirst("gitdir: ".count))
    return target.hasPrefix("/")
      ? URL(fileURLWithPath: target, isDirectory: true)
      : checkout.appendingPathComponent(target, isDirectory: true).standardizedFileURL
  }

  private static func samePath(_ a: URL, _ b: URL) -> Bool {
    a.resolvingSymlinksInPath().standardizedFileURL.path
      == b.resolvingSymlinksInPath().standardizedFileURL.path
  }

  /// A record whose path is now someone else's directory. Its own admin
  /// directory goes, not every record prune would take; see worktrees.md.
  func forgetStale(_ worktree: Worktree, in project: Project) async throws {
    // A `.git` there is another repository's, which prune would keep too.
    let taken = FileManager.default.fileExists(
      atPath: worktree.path.appendingPathComponent(".git").path)
    guard !taken, let record = try await record(of: worktree.path, in: project) else {
      throw NotTheCheckout(path: worktree.path)
    }
    try FileManager.default.removeItem(at: record)
    guard await !isListed(worktree.path, in: project) else {
      throw NotTheCheckout(path: worktree.path)
    }
  }

  /// The directory under `<common>/worktrees` whose `gitdir` names `checkout`,
  /// absolute or, as `worktree.useRelativePaths` writes it, relative to itself.
  private func record(of checkout: URL, in project: Project) async throws -> URL? {
    let records = try await commonGitDirectory(project)
      .appendingPathComponent("worktrees", isDirectory: true)
    let names =
      (try? FileManager.default.contentsOfDirectory(
        at: records, includingPropertiesForKeys: nil)) ?? []
    return names.first { record in
      guard
        let gitdir = try? String(
          contentsOf: record.appendingPathComponent("gitdir"), encoding: .utf8),
        let line = gitdir.split(whereSeparator: \.isNewline).first
      else { return false }
      let target =
        line.hasPrefix("/")
        ? URL(fileURLWithPath: String(line))
        : record.appendingPathComponent(String(line)).standardizedFileURL
      return Self.samePath(target.deletingLastPathComponent(), checkout)
    }
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
    _ = await git.output(["update-index", "-q", "--refresh"], in: worktree)
  }

  /// Only `--verify --quiet`'s exit 1 says missing: a git that failed any other
  /// way says nothing, and the caller would `branch -D` on the answer.
  func lacksBranch(_ branch: String, in project: Project) async -> Bool {
    await git.status(
      ["rev-parse", "--verify", "--quiet", "refs/heads/" + branch], in: project.path) == 1
  }

  /// `worktree remove` with no `--force`, which refuses a tree holding anything
  /// git would lose. Quiet: a path git does not list is simply refused.
  func removeUnchanged(_ path: URL, in project: Project) async {
    _ = try? await git.run(["worktree", "remove", path.path], in: project.path)
  }

  /// `-D`, a branch cut from another start point being unmerged into HEAD.
  /// Kept where a worktree still lists it, as a SIGKILL can leave the record.
  func deleteBranchIfUnlisted(_ branch: String, in project: Project) async {
    guard let listed = try? await list(project), !listed.contains(where: { $0.branch == branch })
    else { return }
    _ = try? await git.run(["branch", "-D", branch], in: project.path)
  }

  /// `git branch -d`, which refuses a branch with commits no other branch
  /// has; `force` is `-D`.
  func deleteBranch(_ branch: String, force: Bool = false, in project: Project) async throws {
    _ = try await git.run(["branch", force ? "-D" : "-d", branch], in: project.path)
  }
}

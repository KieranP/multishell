import Foundation

/// A linked checkout belonging to a `Project`.
///
/// Like `Project`, identity is the path. Worktrees are rediscovered from
/// `git worktree list` on every refresh, so any id we minted ourselves would
/// change out from under persisted selection state.
public struct Worktree: Identifiable, Codable, Hashable, Sendable {
  /// Normalised by `Project.directory` in both initialisers; see `Project`.
  public private(set) var path: URL
  public var projectID: Project.ID
  public var head: String
  public var branch: String?
  public var isPrimary: Bool
  public var isLocked: Bool
  /// The repository itself in a bare layout: listed first by git, with no
  /// checkout to show a status for.
  public var isBare: Bool
  /// When the directory was made, read off the filesystem at discovery;
  /// `nil` where it could not be. git records no creation time for a
  /// worktree, and the directory `git worktree add` makes is the closest
  /// thing there is. A worktree whose directory was copied in, or one on a
  /// filesystem that keeps no birth time, has none, and the date orders
  /// sort it last rather than pretend it is the oldest.
  public var createdAt: Date?

  /// Synthesized decoding would keep whatever URL was written, so the
  /// directory normalisation from `init` is applied here too.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.path = Project.directory(try container.decode(URL.self, forKey: .path))
    self.projectID = try container.decode(Project.ID.self, forKey: .projectID)
    self.head = try container.decodeIfPresent(String.self, forKey: .head) ?? ""
    self.branch = try container.decodeIfPresent(String.self, forKey: .branch)
    self.isPrimary = try container.decodeIfPresent(Bool.self, forKey: .isPrimary) ?? false
    self.isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
    self.isBare = try container.decodeIfPresent(Bool.self, forKey: .isBare) ?? false
    // `try?`, as `ProjectSettings` does for its tint: a date a newer build
    // wrote in another shape costs the date, not the worktree. Worktrees
    // decode lossily, so throwing here would drop the row, and the tabs
    // saved under it, until the next refresh.
    self.createdAt = (try? container.decodeIfPresent(Date.self, forKey: .createdAt)) ?? nil
  }

  public var id: String { path.path }
  /// The branch, the short SHA when detached, or the folder for a bare
  /// repository, which has neither.
  public var name: String {
    if isBare { return path.lastPathComponent }
    return branch ?? String(head.prefix(7))
  }
  public var isDetached: Bool { branch == nil && !isBare }

  public init(
    path: URL,
    projectID: Project.ID,
    head: String,
    branch: String? = nil,
    isPrimary: Bool = false,
    isLocked: Bool = false,
    isBare: Bool = false,
    createdAt: Date? = nil
  ) {
    self.path = Project.directory(path)
    self.projectID = projectID
    self.head = head
    self.branch = branch
    self.isPrimary = isPrimary
    self.isLocked = isLocked
    self.isBare = isBare
    self.createdAt = createdAt
  }
}

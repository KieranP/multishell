import Foundation

/// A linked checkout belonging to a `Project`. Identity is the path, these
/// being rediscovered from `git worktree list` on every refresh.
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
  /// When the directory was made, git recording no creation time. `nil` for
  /// a copied directory or a filesystem with no birth time, sorted last.
  public var createdAt: Date?

  /// Synthesized decoding would keep whatever URL was written, so the
  /// directory normalisation from `init` is applied here too.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.path = Project.directory(try container.decode(URL.self, forKey: .path))
    self.projectID = try container.decode(Project.ID.self, forKey: .projectID)
    self.head = try container.decode(String.self, forKey: .head, or: "")
    self.branch = try container.decodeIfPresent(String.self, forKey: .branch)
    self.isPrimary = try container.decode(Bool.self, forKey: .isPrimary, or: false)
    self.isLocked = try container.decode(Bool.self, forKey: .isLocked, or: false)
    self.isBare = try container.decode(Bool.self, forKey: .isBare, or: false)
    // Tolerated: a date in a shape a newer build wrote costs the date, not
    // the worktree and the tabs saved under it.
    self.createdAt = container.decodeTolerantly(Date.self, forKey: .createdAt)
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

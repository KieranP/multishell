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

  /// Synthesized decoding would keep whatever URL was written, so the
  /// directory normalisation from `init` is applied here too.
  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.path = Project.directory(try c.decode(URL.self, forKey: .path))
    self.projectID = try c.decode(Project.ID.self, forKey: .projectID)
    self.head = try c.decodeIfPresent(String.self, forKey: .head) ?? ""
    self.branch = try c.decodeIfPresent(String.self, forKey: .branch)
    self.isPrimary = try c.decodeIfPresent(Bool.self, forKey: .isPrimary) ?? false
    self.isLocked = try c.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
  }

  public var id: String { path.path }
  public var name: String { branch ?? String(head.prefix(7)) }
  public var isDetached: Bool { branch == nil }

  public init(
    path: URL,
    projectID: Project.ID,
    head: String,
    branch: String? = nil,
    isPrimary: Bool = false,
    isLocked: Bool = false
  ) {
    self.path = Project.directory(path)
    self.projectID = projectID
    self.head = head
    self.branch = branch
    self.isPrimary = isPrimary
    self.isLocked = isLocked
  }
}

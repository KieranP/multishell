import Foundation

/// A read-only tab showing one file of its worktree. It holds no process, so a
/// relaunch reopens it from its path; see Docs/design/files.md.
public struct FileTab: Identifiable, Codable, Hashable, Sendable {
  public let id: UUID
  public let worktreeID: Worktree.ID
  /// The group this tab's strip is part of; see `TabGroup`.
  public internal(set) var groupID: TabGroup.ID
  /// Relative to the worktree, as git lists it. A tab never leaves its
  /// worktree, so the path never changes either.
  public let path: String
  /// Written at quit, not on each scroll, which would save and redraw the
  /// workspace dozens of times a second.
  public internal(set) var scroll: FileTabScroll?

  /// The last part of `path`, which titles the tab where no other open file
  /// shares it.
  public var fileName: String { String(path.split(separator: "/").last ?? Substring(path)) }

  init(worktreeID: Worktree.ID, groupID: TabGroup.ID, path: String) {
    self.id = UUID()
    self.worktreeID = worktreeID
    self.groupID = groupID
    self.path = path
  }

  /// Everything but the group is required, a tab naming no file being no tab.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(UUID.self, forKey: .id)
    self.worktreeID = try container.decode(Worktree.ID.self, forKey: .worktreeID)
    self.groupID = container.decodeTolerantly(
      TabGroup.ID.self,
      forKey: .groupID,
      or: TabGroup.unassigned,
    )
    self.path = try container.decode(String.self, forKey: .path)
    self.scroll = try? container.decodeIfPresent(FileTabScroll.self, forKey: .scroll)
  }

  /// Whether `path` names something inside a worktree: relative, with no `..`
  /// and no empty part. A hand edit could otherwise point a tab anywhere.
  public static func isContained(_ path: String) -> Bool {
    let parts = path.split(separator: "/", omittingEmptySubsequences: false)
    return !path.isEmpty && !parts.contains { $0.isEmpty || $0 == ".." || $0 == "." }
  }
}

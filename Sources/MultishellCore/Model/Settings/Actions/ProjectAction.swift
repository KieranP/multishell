import Foundation

/// A command a project's worktrees keep needing, such as Start Server, run on
/// request in a tab of its own; see Docs/design/actions.md.
public struct ProjectAction: Codable, Hashable, Identifiable, Sendable {
  /// Named so the file's entries this build cannot read are matched by name.
  enum CodingKeys: String, CodingKey {
    case name, command
  }

  /// The Actions page's row, kept through an edit so its fields keep focus.
  /// Never stored, and no part of what makes two actions equal.
  public let id: UUID
  public let name: String
  /// An sh script, run as a hook runs, the worktree's values in variables.
  public let command: String

  /// A row added blank has none until named, so takes no keys yet.
  public var hasName: Bool { name.trimmedOfAllWhitespaceOrNil != nil }

  /// Whether it has a name and a command: a row the Actions page has not
  /// filled in yet runs nothing and is never exported.
  public var isFilledIn: Bool { hasName && command.trimmedOfAllWhitespaceOrNil != nil }

  public init(name: String, command: String) {
    self.init(id: UUID(), name: name, command: command)
  }

  private init(id: UUID, name: String, command: String) {
    self.id = id
    self.name = name
    self.command = command
  }

  /// A blank name or command throws, so a list's lossy read drops that entry:
  /// neither can be shown or run.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let name = try container.decode(String.self, forKey: .name)
    let command = try container.decode(String.self, forKey: .command)
    guard let trimmedName = name.trimmedOfAllWhitespaceOrNil,
      command.trimmedOfAllWhitespaceOrNil != nil
    else {
      throw DecodingError.dataCorruptedError(
        forKey: .name,
        in: container,
        debugDescription: "an action needs a name and a command",
      )
    }
    self.init(name: trimmedName, command: command)
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.name == rhs.name && lhs.command == rhs.command
  }

  public func renamed(_ name: String) -> Self {
    Self(id: id, name: name, command: command)
  }

  public func withCommand(_ command: String) -> Self {
    Self(id: id, name: name, command: command)
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(name)
    hasher.combine(command)
  }
}

import MultishellCore

/// A project override the repository's file may also set, its two fields
/// paired once so a form cannot read one and write another.
public struct InheritableSetting<Value: Equatable & Sendable> {
  /// What the override writes.
  public let project: WritableKeyPath<ProjectSettings, Value?>
  /// Where the file's value is read from when there is no override.
  let shared: KeyPath<SharedProjectSettings, Value?>
}

extension InheritableSetting<String> {
  public static var worktreeDirectory: Self {
    Self(project: \.worktreeDirectory, shared: \.worktreeDirectory)
  }

  public static var branchPrefix: Self {
    Self(project: \.branchPrefix, shared: \.branchPrefix)
  }
}

extension InheritableSetting<WorktreeSortOrder> {
  public static var worktreeSortOrder: Self {
    Self(project: \.worktreeSortOrder, shared: \.worktreeSortOrder)
  }
}

extension InheritableSetting<Bool> {
  public static var showsActiveWorktreesFirst: Self {
    Self(project: \.showsActiveWorktreesFirst, shared: \.showsActiveWorktreesFirst)
  }

  public static var autoStartAgent: Self {
    Self(project: \.autoStartAgent, shared: \.autoStartAgent)
  }

  public static var autoStartAgentOnCreate: Self {
    Self(project: \.autoStartAgentOnCreate, shared: \.autoStartAgentOnCreate)
  }

  public static var opensTerminalOnSelect: Self {
    Self(project: \.opensTerminalOnSelect, shared: \.opensTerminalOnSelect)
  }

  public static var opensTerminalOnCreate: Self {
    Self(project: \.opensTerminalOnCreate, shared: \.opensTerminalOnCreate)
  }
}

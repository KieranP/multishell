import Foundation
import MultishellCore

// Declared order is the order allCases gives the UI.
// swiftlint:disable sorted_enum_cases
/// What a project hook is told, and what the settings panel calls each
/// variable. One list, so neither can gain a case without the other.
public enum HookVariable: CaseIterable, Sendable {
  case projectPath
  case projectName
  case worktreePath
  case branch
  case port

  /// Spelled by the placeholder meaning the same, so a custom command and a
  /// hook read one name.
  public var name: String {
    switch self {
    case .projectPath: WorktreePlaceholder.projectPath.variable
    case .projectName: WorktreePlaceholder.projectName.variable
    case .worktreePath: WorktreePlaceholder.worktreePath.variable
    case .branch: WorktreePlaceholder.branch.variable
    case .port: WorktreePlaceholder.port.variable
    }
  }

  /// The one-line description the Hooks tab shows beside the name.
  public var meaning: String {
    switch self {
    case .projectPath: t("hook-variable.project-path")
    case .projectName: t("hook-variable.project-name")
    case .worktreePath: t("hook-variable.worktree-path")
    case .branch: t("hook-variable.branch")
    case .port: t("hook-variable.port")
    }
  }

  /// A port for a worktree with none, unset after the rc files. A set value is
  /// never written into the script, any value being shell text there.
  static func namesToUnset(port: Int?) -> [String] {
    port == nil ? [Self.port.name] : []
  }

  /// `port` is `nil` where the worktree has no block, which leaves its variable unset.
  static func environment(
    project: Project,
    worktreePath: URL,
    branch: String,
    port: Int?,
  ) -> [String: String] {
    var environment: [String: String] = [:]
    for variable in allCases {
      environment[variable.name] =
        switch variable {
        case .projectPath: project.path.path
        case .projectName: project.name
        case .worktreePath: worktreePath.path
        case .branch: branch
        case .port: port.map(String.init)
        }
    }
    return environment
  }
}
// swiftlint:enable sorted_enum_cases

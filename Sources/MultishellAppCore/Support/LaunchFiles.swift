import Foundation
import MultishellCore

/// What a launch rewrites on disk before a terminal opens, all the account's
/// own: the helper link and shell integration. Never an agent's hook file.
enum LaunchFiles {
  static func refresh(helper: URL?) -> (any Error)? {
    do {
      try HelperLink.refresh(to: helper)
      try ShellIntegration.refresh()
      return nil
    } catch {
      return error
    }
  }
}

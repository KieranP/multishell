import Foundation
import MultishellCore

/// What a launch rewrites on disk before a terminal opens, all the account's
/// own: the helper links and shell integration. Never an agent's hook file.
enum AppLaunchFiles {
  /// Each is tried whatever the others did, the first failure thrown after.
  static func write(
    helper: URL?,
    links: [URL] = [Paths.helperLink, Paths.buildHelperLink],
    writeShellIntegration: () throws -> Void = { try ShellIntegration.write() },
  ) throws {
    var firstFailure: (any Error)?
    for link in links {
      do { try HelperLink.point(link, at: helper) } catch {
        firstFailure = firstFailure ?? error
      }
    }
    do { try writeShellIntegration() } catch { firstFailure = firstFailure ?? error }
    if let firstFailure { throw firstFailure }
  }
}

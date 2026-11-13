import Foundation

/// Export found the repository's file there but not JSON, and left it as it was:
/// rewriting it would drop whatever it holds.
struct UnreadableSharedSettingsFile: Error {
  let file: URL
  let underlying: any Error
}

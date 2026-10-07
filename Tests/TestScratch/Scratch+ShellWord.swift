import Foundation
import MultishellProcess

extension Scratch {
  /// A path as one word to any shell, for a suite with no process layer of its
  /// own to quote it with.
  public static func shellWord(_ path: String) -> String {
    AnyShellQuoting.quote(path)
  }
}

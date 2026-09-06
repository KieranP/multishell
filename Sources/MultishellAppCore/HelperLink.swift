import Foundation
import MultishellCore

/// Keeps the helper reachable from outside the bundle.
///
/// The hook lines in `~/.claude/settings.json` reference a stable path under
/// the state directory; this refreshes that link at launch so a moved or
/// updated bundle still answers. The optional link on the default PATH is for
/// people writing their own hooks, the way editors install their CLI; the
/// platform makes that one, since it needs a privilege prompt.
public enum HelperLink {
  public static let commandLineToolLink = URL(fileURLWithPath: "/usr/local/bin/multishell")

  /// Points `link` at `helper`, replacing whatever was there. Nothing to do
  /// when there is no bundled helper.
  public static func refresh(to helper: URL?, link: URL = Paths.helperLink) throws {
    guard let helper else { return }
    let manager = FileManager.default
    try manager.createDirectory(
      at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
    if let existing = try? manager.destinationOfSymbolicLink(atPath: link.path),
      existing == helper.path
    {
      return
    }
    try? manager.removeItem(at: link)
    try manager.createSymbolicLink(at: link, withDestinationURL: helper)
  }

  public static var isCommandLineToolInstalled: Bool {
    FileManager.default.fileExists(atPath: commandLineToolLink.path)
  }
}

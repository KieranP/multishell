import Foundation
import MultishellCore

/// What the app's own executable passes to the helper: a shell that rebuilds
/// PATH can still find the app as `multishell` in `Contents/MacOS`; terminals.md.
public enum HelperHandOff {
  /// `nil` starts the app: no arguments, or AppKit's own, which are a single
  /// dash and a name, as `-psn_` and `-AppleLanguages` are.
  public static func helperArguments(from arguments: [String]) -> [String]? {
    let given = Array(arguments.dropFirst())
    guard let first = given.first else { return nil }
    let isAppKitArgument = first.hasPrefix("-") && !first.hasPrefix("--") && first != "-h"
    return isAppKitArgument ? nil : given
  }

  /// Through any link to `executable`: `Bundle.main.bundleURL` is the link's
  /// own directory then, as from `ln -s …/Contents/MacOS/Multishell ~/bin`.
  public static func helper(inBundleOf executable: URL) -> URL? {
    guard let app = executable.enclosingAppBundle else { return nil }
    let helper = app.appendingPathComponent("Contents/Helpers/multishell", isDirectory: false)
    return FileManager.default.isExecutableFile(atPath: helper.path) ? helper : nil
  }

  /// `nil` outside a bundle, where there is no helper to put first.
  public static func bundleDirectories(of executable: URL) -> BundleDirectories? {
    guard let helper = helper(inBundleOf: executable) else { return nil }
    return BundleDirectories(
      helper: helper.deletingLastPathComponent(),
      app: executable.resolvingSymlinksInPath().deletingLastPathComponent(),
    )
  }
}

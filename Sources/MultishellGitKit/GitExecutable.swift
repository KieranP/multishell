import Foundation
import MultishellProcess

/// Which git to run. Apple's `/usr/bin/git` is a shim that looks up the
/// developer tools' git on every call, about 3.6 ms each; see architecture.md.
enum GitExecutable {
  /// The PATH's git, or where the shim leads when that is the shim. The shim
  /// stays where xcrun cannot say, as a git that runs beats none.
  static func resolve(
    path: String?, shim: URL = URL(fileURLWithPath: "/usr/bin/git"),
    xcrun: URL = URL(fileURLWithPath: "/usr/bin/xcrun"),
    developerDirectory: URL? = selectedDeveloperDirectory()
  ) async -> URL? {
    guard let found = ExecutableLookup.find("git", path: path) else { return nil }
    guard found.standardizedFileURL.path == shim.standardizedFileURL.path else { return found }
    // With no developer tools xcrun may raise their install dialog, at every launch.
    guard let developerDirectory,
      FileManager.default.fileExists(atPath: developerDirectory.path)
    else { return found }
    guard
      let output = try? await ProcessRunner().capture(
        xcrun, ["--find", "git"], in: URL(fileURLWithPath: "/"), timeout: .seconds(5)),
      output.succeeded
    else { return found }
    let resolved = output.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !resolved.isEmpty, FileManager.default.isExecutableFile(atPath: resolved) else {
      return found
    }
    return URL(fileURLWithPath: resolved)
  }

  /// Where xcrun would look, in its order: `DEVELOPER_DIR`, xcode-select's
  /// link, then its two defaults. Read off the disk, as asking is a launch.
  static func selectedDeveloperDirectory(
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> URL? {
    if let directory = environment["DEVELOPER_DIR"], !directory.isEmpty {
      return URL(fileURLWithPath: directory)
    }
    let manager = FileManager.default
    if let linked = try? manager.destinationOfSymbolicLink(atPath: "/var/db/xcode_select_link") {
      return URL(fileURLWithPath: linked)
    }
    return ["/Applications/Xcode.app/Contents/Developer", "/Library/Developer/CommandLineTools"]
      .map { URL(fileURLWithPath: $0) }
      .first { manager.fileExists(atPath: $0.path) }
  }
}

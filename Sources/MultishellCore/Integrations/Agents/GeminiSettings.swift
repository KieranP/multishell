import Foundation

/// Whether Gemini starts a turn of its own when a background shell ends,
/// which only two settings together make it do; see Docs/design/agents.md.
enum GeminiSettings {
  /// The ones Gemini reads that name a turn a shell's end starts.
  private static let waking: Set<String> = ["inject", "notify"]

  static func wakesForBackgroundShells(environment: [String: String], workspace: String?) -> Bool {
    var steering = false
    var completion = "silent"
    // Gemini's merge order, the last word winning.
    for settings in merged(environment: environment, workspace: workspace) {
      if let value = (settings["experimental"] as? [String: Any])?["modelSteering"] as? Bool {
        steering = value
      }
      let shell = (settings["tools"] as? [String: Any])?["shell"] as? [String: Any]
      if let value = shell?["backgroundCompletionBehavior"] as? String { completion = value }
    }
    return steering && waking.contains(completion)
  }

  /// System defaults, user, project, system; the project's only where Gemini
  /// trusts it.
  private static func merged(
    environment: [String: String], workspace: String?
  ) -> [[String: Any]] {
    let geminiDirectory = geminiDirectory(environment)
    let systemFile = URL(
      fileURLWithPath: environment["GEMINI_CLI_SYSTEM_SETTINGS_PATH"]
        ?? "/Library/Application Support/GeminiCli/settings.json")
    let defaults = read(
      environment["GEMINI_CLI_SYSTEM_DEFAULTS_PATH"].map(URL.init(fileURLWithPath:))
        ?? systemFile.deletingLastPathComponent().appendingPathComponent("system-defaults.json"))
    let user = read(geminiDirectory.appendingPathComponent("settings.json"))
    let system = read(systemFile)
    var project: [String: Any]?
    let outside = [defaults, user, system].compactMap { $0 }
    if let workspace, isTrusted(workspace, environment: environment, settings: outside) {
      project = read(
        URL(fileURLWithPath: workspace).appendingPathComponent(".gemini/settings.json"))
    }
    return [defaults, user, project, system].compactMap { $0 }
  }

  private static func geminiDirectory(_ environment: [String: String]) -> URL {
    let home =
      environment["GEMINI_CLI_HOME"].flatMap { $0.isEmpty ? nil : $0 }
      ?? environment["HOME"] ?? NSHomeDirectory()
    return URL(fileURLWithPath: home).appendingPathComponent(".gemini")
  }

  /// Gemini's own rule: the longest rule path naming the folder decides, a
  /// parent rule standing for the folder above it, and no rule is no trust.
  private static func isTrusted(
    _ workspace: String, environment: [String: String], settings: [[String: Any]]
  ) -> Bool {
    if environment["GEMINI_CLI_TRUST_WORKSPACE"] == "true" { return true }
    let enabled = settings.reduce(true) { enabled, file in
      let trust = (file["security"] as? [String: Any])?["folderTrust"] as? [String: Any]
      return trust?["enabled"] as? Bool ?? enabled
    }
    guard enabled else { return true }
    let rulesFile =
      environment["GEMINI_CLI_TRUSTED_FOLDERS_PATH"].map(URL.init(fileURLWithPath:))
      ?? geminiDirectory(environment).appendingPathComponent("trustedFolders.json")
    guard let rules = read(rulesFile) as? [String: String] else { return false }
    let folder = resolved(workspace)
    let decisive = rules.filter { path, level in
      let covered = level == "TRUST_PARENT" ? (path as NSString).deletingLastPathComponent : path
      let root = resolved(covered)
      return folder == root || folder.hasPrefix(root.hasSuffix("/") ? root : root + "/")
    }.max { $0.key.count < $1.key.count }
    return decisive.map { $0.value == "TRUST_FOLDER" || $0.value == "TRUST_PARENT" } ?? false
  }

  private static func resolved(_ path: String) -> String {
    URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path
  }

  private static func read(_ file: URL) -> [String: Any]? {
    guard let text = try? String(contentsOf: file, encoding: .utf8) else { return nil }
    return try? JSONSerialization.jsonObject(with: Data(withoutComments(text).utf8))
      as? [String: Any]
  }

  /// Gemini reads its settings with comments allowed, so they go, and only
  /// outside strings, where a URL's `//` is text.
  static func withoutComments(_ text: String) -> String {
    var out = ""
    var characters = text.makeIterator()
    var inString = false
    var pending = characters.next()
    while let character = pending {
      pending = characters.next()
      if inString {
        out.append(character)
        if character == "\\", let escaped = pending {
          out.append(escaped)
          pending = characters.next()
        } else if character == "\"" {
          inString = false
        }
      } else if character == "/", pending == "/" {
        while let skipped = pending, skipped != "\n" { pending = characters.next() }
      } else if character == "/", pending == "*" {
        pending = characters.next()
        var previous: Character?
        while let skipped = pending {
          pending = characters.next()
          if previous == "*", skipped == "/" { break }
          previous = skipped
        }
      } else {
        if character == "\"" { inString = true }
        out.append(character)
      }
    }
    return out
  }
}

import Foundation

/// Whether Gemini starts a turn of its own when a background shell ends,
/// which only two settings together make it do; see Docs/design/agents.md.
enum GeminiSettings {
  /// The ones Gemini reads that name a turn a shell's end starts.
  private static let wakingCompletionBehaviors: Set<String> = ["inject", "notify"]

  static func wakesForBackgroundShells(environment: [String: String], directory: String?) -> Bool {
    var steering = false
    var completion = "silent"
    // Gemini's merge order, the last word winning.
    for settings in layersInMergeOrder(environment: environment, directory: directory) {
      if let value = (settings["experimental"] as? [String: Any])?["modelSteering"] as? Bool {
        steering = value
      }
      let shell = (settings["tools"] as? [String: Any])?["shell"] as? [String: Any]
      if let value = shell?["backgroundCompletionBehavior"] as? String { completion = value }
    }
    return steering && wakingCompletionBehaviors.contains(completion)
  }

  /// System defaults, user, project, system; the project's only where Gemini
  /// trusts it.
  private static func layersInMergeOrder(
    environment: [String: String], directory: String?
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
    if let directory, isTrusted(directory, environment: environment, settings: outside) {
      project = read(
        URL(fileURLWithPath: directory).appendingPathComponent(".gemini/settings.json"))
    }
    return [defaults, user, project, system].compactMap { $0 }
  }

  /// An empty `HOME` is Gemini's cue for the temporary directory, unlike
  /// `underHome`'s fallback to the account's home.
  private static func geminiDirectory(_ environment: [String: String]) -> URL {
    let home =
      environment["GEMINI_CLI_HOME"]?.nonEmpty
      ?? environment["HOME"] ?? NSHomeDirectory()
    let base = home.isEmpty ? nodeTemporaryDirectory(environment) : home
    return URL(fileURLWithPath: base).appendingPathComponent(".gemini")
  }

  /// Node's `os.tmpdir()`: the first set of three variables, its trailing
  /// slash dropped, else `/tmp`.
  private static func nodeTemporaryDirectory(_ environment: [String: String]) -> String {
    let named = ["TMPDIR", "TMP", "TEMP"].lazy.compactMap { environment[$0] }
    guard let directory = named.first(where: { !$0.isEmpty }) else { return "/tmp" }
    return directory.count > 1 && directory.hasSuffix("/")
      ? String(directory.dropLast()) : directory
  }

  /// Gemini's own rule: the longest rule path naming the folder decides, a
  /// parent rule standing for the folder above it, and no rule is no trust.
  private static func isTrusted(
    _ directory: String, environment: [String: String], settings: [[String: Any]]
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
    let folder = URL(fileURLWithPath: resolved(directory))
    let decisive = rules.filter { path, level in
      let covered = level == "TRUST_PARENT" ? (path as NSString).deletingLastPathComponent : path
      return folder.pathComponents(under: URL(fileURLWithPath: resolved(covered))) != nil
    }.max { $0.key.count < $1.key.count }
    return decisive.map { $0.value == "TRUST_FOLDER" || $0.value == "TRUST_PARENT" } ?? false
  }

  private static func resolved(_ path: String) -> String {
    URL(fileURLWithPath: path).comparablePath
  }

  /// Gemini reads its settings with comments allowed.
  private static func read(_ file: URL) -> [String: Any]? {
    guard let text = try? String(contentsOf: file, encoding: .utf8) else { return nil }
    return try? JSONSerialization.jsonObject(with: Data(text.withoutJSONComments.utf8))
      as? [String: Any]
  }
}

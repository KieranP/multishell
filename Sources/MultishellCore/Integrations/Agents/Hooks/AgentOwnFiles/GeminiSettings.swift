import Foundation

/// Whether Gemini starts a turn of its own when a background shell ends,
/// which only two settings together make it do; see Docs/design/agents/background-work.md.
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
    environment: [String: String],
    directory: String?,
  ) -> [[String: Any]] {
    let geminiDirectory = geminiDirectory(environment)
    let systemFile = URL(
      fileURLWithPath: environment["GEMINI_CLI_SYSTEM_SETTINGS_PATH"]?.nonEmpty
        ?? "/Library/Application Support/GeminiCli/settings.json"
    )
    let defaults = read(
      environment["GEMINI_CLI_SYSTEM_DEFAULTS_PATH"]?.nonEmpty.map(URL.init(fileURLWithPath:))
        ?? systemFile.deletingLastPathComponent().appendingPathComponent("system-defaults.json")
    )
    let user = read(geminiDirectory.appendingPathComponent("settings.json"))
    let system = read(systemFile)
    var project: [String: Any]?
    let outside = [defaults, user, system].compactMap(\.self)
    if let directory, isTrusted(directory, environment: environment, settings: outside) {
      project = read(
        URL(fileURLWithPath: directory).appendingPathComponent(".gemini/settings.json")
      )
    }
    return [defaults, user, project, system].compactMap(\.self)
  }

  /// An empty `HOME` is Gemini's cue for the temporary directory, unlike
  /// `AgentHookCatalogue.home`'s fallback to the account's home.
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

  /// Gemini's own rule: a refusal in the environment, then the folder rules.
  private static func isTrusted(
    _ directory: String,
    environment: [String: String],
    settings: [[String: Any]],
  ) -> Bool {
    // Checked first, as Gemini 0.66's checkPathTrust does: a refusal outranks every rule.
    if environment["GEMINI_RESTRICTED_MODE"] == "true"
      || environment["GEMINI_CLI_TRUST_WORKSPACE"] == "false"
    {
      return false
    }
    if environment["GEMINI_CLI_TRUST_WORKSPACE"] == "true" { return true }
    let enabled = settings.reduce(true) { enabled, file in
      let trust = (file["security"] as? [String: Any])?["folderTrust"] as? [String: Any]
      return trust?["enabled"] as? Bool ?? enabled
    }
    guard enabled else { return true }
    // Gemini tests each path variable for truth, so an empty one is unset.
    let rulesFile =
      environment["GEMINI_CLI_TRUSTED_FOLDERS_PATH"]?.nonEmpty.map(URL.init(fileURLWithPath:))
      ?? geminiDirectory(environment).appendingPathComponent("trustedFolders.json")
    guard let text = try? String(contentsOf: rulesFile, encoding: .utf8),
      let rules = GeminiTrustedFolders(text: text)
    else { return false }
    return rules.trusts(directory)
  }

  /// Gemini reads its settings with comments allowed.
  private static func read(_ file: URL) -> [String: Any]? {
    guard let text = try? String(contentsOf: file, encoding: .utf8) else { return nil }
    return try? JSONSerialization.jsonObject(with: Data(text.withoutJSONComments.utf8))
      as? [String: Any]
  }
}

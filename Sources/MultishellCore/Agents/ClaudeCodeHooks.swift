import Foundation

/// The hook entries Claude Code needs to report its state, and how they are
/// added to and removed from a settings file without touching anything else
/// in it.
///
/// Claude reads hooks from `~/.claude/settings.json`. Every event runs one
/// command: the helper, through the stable link under the state directory,
/// so a moved app bundle does not break the hooks. The command exits 0 when
/// the helper is missing, so an uninstalled Multishell costs nothing.
public enum ClaudeCodeHooks {
  public static let subcommand = "claude-hook"
  /// Claude kills a hook that runs longer than this. The helper connects,
  /// writes one line and exits; anything longer means the app is wedged.
  public static let timeoutSeconds = 5

  public static var userSettingsFile: URL {
    FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".claude", isDirectory: true)
      .appendingPathComponent("settings.json", isDirectory: false)
  }

  /// The helper as a hook should reference it: through `$HOME`, so a synced
  /// dotfile still resolves on another machine.
  public static var helperReference: String {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let link = Paths.helperLink.path
    guard link.hasPrefix(home + "/") else { return link }
    return "$HOME" + link.dropFirst(home.count)
  }

  /// `exec`, so the hook is one process rather than a shell waiting on the
  /// helper; the helper finds Claude's pid by walking past shells anyway.
  /// No variable assignment: the line must parse in fish as well as sh,
  /// since which shell Claude runs hooks through is not ours to choose.
  public static func command(helper: String = helperReference) -> String {
    "[ -x \"\(helper)\" ] && exec \"\(helper)\" \(subcommand); exit 0"
  }

  public static func isMultishellHook(_ command: String) -> Bool {
    command.contains("multishell") && command.contains(subcommand)
  }

  /// `{ "hooks": { event: [ { "hooks": [ ... ] } ] } }`, Claude's shape.
  public static func entries(helper: String = helperReference) -> [String: Any] {
    var hooks: [String: Any] = [:]
    for event in ClaudeHookPayload.hookedEvents {
      hooks[event] = [group(helper: helper)]
    }
    return ["hooks": hooks]
  }

  private static func group(helper: String) -> [String: Any] {
    ["hooks": [["type": "command", "command": command(helper: helper), "timeout": timeoutSeconds]]]
  }

  /// What the settings window shows and the clipboard gets.
  public static func snippet(helper: String = helperReference) -> String {
    Self.render(entries(helper: helper))
  }

  public static func isInstalled(in settings: [String: Any]) -> Bool {
    let hooks = settings["hooks"] as? [String: Any] ?? [:]
    return ClaudeHookPayload.hookedEvents.allSatisfy { event in
      groups(hooks[event]).contains(where: isMultishellGroup)
    }
  }

  /// Every event gets one entry of ours; entries already there, ours or
  /// anyone else's, are left as they are.
  public static func adding(
    to settings: [String: Any], helper: String = helperReference
  )
    -> [String: Any]
  {
    var result = settings
    var hooks = settings["hooks"] as? [String: Any] ?? [:]
    for event in ClaudeHookPayload.hookedEvents {
      var existing = groups(hooks[event])
      if !existing.contains(where: isMultishellGroup) {
        existing.append(group(helper: helper))
      }
      hooks[event] = existing
    }
    result["hooks"] = hooks
    return result
  }

  /// Removes our entries from every event, leaving other hooks and an
  /// event with none of them left is dropped rather than left as `[]`.
  public static func removing(from settings: [String: Any]) -> [String: Any] {
    var result = settings
    guard var hooks = settings["hooks"] as? [String: Any] else { return result }
    for (event, value) in hooks {
      let kept = groups(value).filter { !isMultishellGroup($0) }
      hooks[event] = kept.isEmpty ? nil : kept
    }
    result["hooks"] = hooks.isEmpty ? nil : hooks
    return result
  }

  private static func groups(_ value: Any?) -> [[String: Any]] {
    value as? [[String: Any]] ?? []
  }

  private static func isMultishellGroup(_ group: [String: Any]) -> Bool {
    let commands = (group["hooks"] as? [[String: Any]] ?? []).compactMap {
      $0["command"] as? String
    }
    return commands.contains(where: isMultishellHook)
  }

  // MARK: - Files

  public static func isInstalled(in file: URL = userSettingsFile) -> Bool {
    guard let settings = try? read(file) else { return false }
    return isInstalled(in: settings)
  }

  /// Adds the hooks to `file`, creating it and its directory if needed. The
  /// file is re-serialised, so its formatting changes; the first write keeps
  /// a copy beside it.
  public static func install(
    into file: URL = userSettingsFile, helper: String = helperReference
  )
    throws
  {
    try write(adding(to: try read(file), helper: helper), to: file)
  }

  public static func remove(from file: URL = userSettingsFile) throws {
    guard FileManager.default.fileExists(atPath: file.path) else { return }
    try write(removing(from: try read(file)), to: file)
  }

  /// An empty object for a missing file; anything that is not a JSON object
  /// is an error, since rewriting it would destroy the user's settings.
  static func read(_ file: URL) throws -> [String: Any] {
    guard FileManager.default.fileExists(atPath: file.path) else { return [:] }
    let data = try Data(contentsOf: file)
    guard data.contains(where: { !" \t\r\n".utf8.contains($0) }) else { return [:] }
    guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw UnexpectedSettingsShape(file: file)
    }
    return object
  }

  private static func write(_ settings: [String: Any], to file: URL) throws {
    let directory = file.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let backup = file.appendingPathExtension("before-multishell")
    if FileManager.default.fileExists(atPath: file.path),
      !FileManager.default.fileExists(atPath: backup.path)
    {
      try FileManager.default.copyItem(at: file, to: backup)
    }
    try Data(render(settings).utf8).write(to: file, options: .atomic)
  }

  private static func render(_ object: [String: Any]) -> String {
    let data =
      (try? JSONSerialization.data(
        withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]))
      ?? Data()
    return String(decoding: data, as: UTF8.self) + "\n"
  }
}

public struct UnexpectedSettingsShape: Error, CustomStringConvertible {
  public let file: URL
  public var description: String {
    "\(file.path) is not a JSON object, so Multishell will not rewrite it."
  }
}

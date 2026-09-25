import Foundation

/// Adding an agent's hooks to a settings object and taking them out again,
/// without touching the disk; see Docs/design/agents.md.
extension AgentHookIntegration {
  /// Whether any hook of ours is in there at all, so a half-written file
  /// still counts.
  func holdsAnyOfOurs(_ settings: [String: Any]) -> Bool {
    events.contains(where: ourHookPredicate(in: settings))
  }

  func ourHookPredicate(in settings: [String: Any]) -> (AgentHookEvent) -> Bool {
    let hooks = hooksSection(settings) ?? [:]
    return { event in
      groups(hooks[event.name])?.contains(where: holdsOurHook) ?? false
    }
  }

  /// One entry of ours per event, everything already there left alone.
  /// `install` refuses a file it cannot read rather than skipping an event.
  func adding(
    to settings: [String: Any], helper: String = AgentHookCatalogue.helperReference
  )
    -> [String: Any]
  {
    var result = settings
    // Left alone where it holds a shape this cannot put back; `install`
    // refuses such a file rather than reaching here.
    guard var hooks = hooksSection(settings) else { return result }
    for event in events {
      guard var existing = groups(hooks[event.name]) else { continue }
      if !existing.contains(where: holdsOurHook) {
        existing.append(group(event, helper: helper))
      }
      hooks[event.name] = existing
    }
    result["hooks"] = hooks
    return result
  }

  /// Removes our entries, leaving other hooks and dropping an event left
  /// empty. Remove takes back what Add put in and nothing else.
  func removing(from settings: [String: Any]) -> [String: Any] {
    var result = settings
    guard var hooks = settings["hooks"] as? [String: Any] else { return result }
    for (event, value) in hooks {
      guard let groups = groups(value) else { continue }
      var changed = false
      var kept: [[String: Any]] = []
      for group in groups {
        guard holdsOurHook(group) else {
          kept.append(group)
          continue
        }
        changed = true
        if let trimmed = withoutOurHooks(group) { kept.append(trimmed) }
      }
      guard changed else { continue }
      hooks[event] = kept.isEmpty ? nil : kept
    }
    result["hooks"] = hooks.isEmpty ? nil : hooks
    return result
  }

  /// What one event holds, `nil` where the file has a shape this cannot
  /// read. Absent reads as an empty list to add to; unreadable does not.
  private func groups(_ value: Any?) -> [[String: Any]]? {
    guard let value else { return [] }
    return value as? [[String: Any]]
  }

  /// The events this would have to write over to install. Empty is the
  /// answer for every file the agents themselves write.
  func unreadableEvents(in settings: [String: Any]) -> [String] {
    let hooks = hooksSection(settings) ?? [:]
    return events.filter { groups(hooks[$0.name]) == nil }.map(\.name)
  }

  /// The file's `hooks`, `nil` where it is not an object of events. Absent
  /// reads as empty, and so does `null`, that being the key spelled out.
  func hooksSection(_ settings: [String: Any]) -> [String: Any]? {
    guard let value = settings["hooks"], !(value is NSNull) else { return [:] }
    return value as? [String: Any]
  }

  /// One entry of the file, whichever of the two shapes it is in: a group
  /// of hooks, or a hook on its own. A mixed group holds one too.
  func holdsOurHook(_ entry: [String: Any]) -> Bool {
    var commands = (entry["hooks"] as? [[String: Any]] ?? []).compactMap {
      $0["command"] as? String
    }
    if let command = entry["command"] as? String { commands.append(command) }
    return commands.contains(where: AgentHookCatalogue.isOurHook)
  }

  /// Ours out of one group, `nil` where nothing of the user's is left; a mixed
  /// group, ours never, keeps theirs. See Docs/design/agents.md.
  private func withoutOurHooks(_ group: [String: Any]) -> [String: Any]? {
    var trimmed = group
    if let command = group["command"] as? String, AgentHookCatalogue.isOurHook(command) {
      for key in Self.bareHookKeys { trimmed[key] = nil }
    }
    if let entries = group["hooks"] as? [[String: Any]] {
      let kept = entries.filter { entry in
        guard let command = entry["command"] as? String else { return true }
        return !AgentHookCatalogue.isOurHook(command)
      }
      trimmed["hooks"] = kept.isEmpty ? nil : kept
    }
    return trimmed["hooks"] != nil || trimmed["command"] != nil ? trimmed : nil
  }

  /// What a bare hook of ours carries; a matcher is the group's and stays.
  private static let bareHookKeys = ["type", "command", "timeout", "timeoutSec"]
}

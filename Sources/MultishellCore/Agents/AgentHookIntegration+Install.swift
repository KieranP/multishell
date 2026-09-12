import Foundation

/// Writing an agent's hooks into its file and taking them out again; see
/// docs/design/agents.md.
extension AgentHookIntegration {
  // MARK: - Merging into a file of the user's

  public func isInstalled(in settings: [String: Any]) -> Bool {
    // An agent with no events has no hooks in any file; without this every
    // settings object would satisfy an empty list.
    guard !events.isEmpty else { return false }
    let hooks = settings["hooks"] as? [String: Any] ?? [:]
    return events.allSatisfy { event in
      groups(hooks[event.name])?.contains(where: isMultishellGroup) ?? false
    }
  }

  /// Whether any hook of ours is in there at all. Not `isInstalled`, which
  /// wants one under every event and so answers no to a half-written file.
  func holdsAnyOfOurs(_ settings: [String: Any]) -> Bool {
    let hooks = settings["hooks"] as? [String: Any] ?? [:]
    return events.contains { event in
      groups(hooks[event.name])?.contains(where: isMultishellGroup) ?? false
    }
  }

  /// One entry of ours per event, everything already there left alone.
  /// `install` refuses a file it cannot read rather than skipping an event.
  public func adding(
    to settings: [String: Any], helper: String = AgentHooks.helperReference
  )
    -> [String: Any]
  {
    var result = settings
    var hooks = settings["hooks"] as? [String: Any] ?? [:]
    for event in events {
      guard var existing = groups(hooks[event.name]) else { continue }
      if !existing.contains(where: isMultishellGroup) {
        existing.append(group(event, helper: helper))
      }
      hooks[event.name] = existing
    }
    result["hooks"] = hooks
    return result
  }

  /// Removes our entries, leaving other hooks and dropping an event left
  /// empty. Remove takes back what Add put in and nothing else.
  public func removing(from settings: [String: Any]) -> [String: Any] {
    var result = settings
    guard var hooks = settings["hooks"] as? [String: Any] else { return result }
    for (event, value) in hooks {
      guard let groups = groups(value) else { continue }
      var changed = false
      var kept: [[String: Any]] = []
      for group in groups {
        guard isMultishellGroup(group) else {
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
    let hooks = settings["hooks"] as? [String: Any] ?? [:]
    return events.filter { groups(hooks[$0.name]) == nil }.map(\.name)
  }

  /// One entry of the file, whichever of the two shapes it is in: a group
  /// of hooks, or a hook on its own.
  private func isMultishellGroup(_ group: [String: Any]) -> Bool {
    var commands = (group["hooks"] as? [[String: Any]] ?? []).compactMap {
      $0["command"] as? String
    }
    if let command = group["command"] as? String { commands.append(command) }
    return commands.contains(where: AgentHooks.isMultishellHook)
  }

  /// Ours taken out of one group, `nil` where nothing of the user's is left.
  /// Add only ever appends its own group, so a mixed one is theirs to keep.
  private func withoutOurHooks(_ group: [String: Any]) -> [String: Any]? {
    guard let entries = group["hooks"] as? [[String: Any]] else { return nil }
    let kept = entries.filter { entry in
      guard let command = entry["command"] as? String else { return true }
      return !AgentHooks.isMultishellHook(command)
    }
    guard !kept.isEmpty else { return nil }
    var trimmed = group
    trimmed["hooks"] = kept
    return trimmed
  }

  // MARK: - Files

  public func isInstalled(in file: URL? = nil) -> Bool {
    let file = file ?? self.file
    if format.isOursAlone {
      guard let contents = try? String(contentsOf: file, encoding: .utf8) else { return false }
      return contents.contains(AgentHooks.helperName)
    }
    guard let settings = try? HookSettingsFile.read(file) else { return false }
    return isInstalled(in: settings)
  }

  public func install(into file: URL? = nil, helper: String = AgentHooks.helperReference) throws {
    let file = file ?? self.file
    if format.isOursAlone {
      try HookSettingsFile.writeOurs(snippet(helper: helper), to: file)
    } else {
      let settings = try HookSettingsFile.read(file)
      if let event = unreadableEvents(in: settings).first {
        throw UnreadableHookEntries(file: file, event: event)
      }
      try HookSettingsFile.write(adding(to: settings, helper: helper), to: file)
    }
  }

  /// A file of ours is deleted, and one that turns out not to be ours is
  /// left where it is: the name is ours, but the file on disk decides.
  public func remove(from file: URL? = nil) throws {
    let file = file ?? self.file
    guard FileManager.default.fileExists(atPath: file.path) else { return }
    if format.isOursAlone {
      guard isInstalled(in: file) else { return }
      try FileManager.default.removeItem(at: file)
    } else {
      // Nothing of ours in it: the write would sort its keys, re-indent it and
      // leave a backup beside it, all for an edit that changes nothing.
      let settings = try HookSettingsFile.read(file)
      guard holdsAnyOfOurs(settings) else { return }
      try HookSettingsFile.write(removing(from: settings), to: file)
    }
  }
}

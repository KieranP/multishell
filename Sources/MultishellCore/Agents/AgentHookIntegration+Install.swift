import Foundation

/// Writing an agent's hooks into its file, and taking them out again.
///
/// A file the user keeps their own settings in is read, merged and written
/// back, with a copy kept the first time; a file of ours alone is written
/// whole and deleted to remove it.
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

  /// Every event gets one entry of ours; entries already there, ours or
  /// anyone else's, are left as they are, and an event holding something
  /// this cannot read is left alone entirely. `install` refuses such a file
  /// rather than leaving that event without its hook in silence.
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

  /// Removes our entries from every event, leaving other hooks; an event
  /// with none of them left is dropped rather than left as `[]`. An event
  /// this cannot read held nothing of ours, so it is left where it is:
  /// Remove takes back what Add put in and nothing else.
  public func removing(from settings: [String: Any]) -> [String: Any] {
    var result = settings
    guard var hooks = settings["hooks"] as? [String: Any] else { return result }
    for (event, value) in hooks {
      guard let groups = groups(value) else { continue }
      let kept = groups.filter { !isMultishellGroup($0) }
      guard kept.count != groups.count else { continue }
      hooks[event] = kept.isEmpty ? nil : kept
    }
    result["hooks"] = hooks.isEmpty ? nil : hooks
    return result
  }

  /// What one event holds, or `nil` when the file has something there this
  /// cannot read: a string, an object, a shape a later version of the agent
  /// takes. Absent reads as the empty list, which is a list we can add to;
  /// unreadable is not, and nothing in it was ever ours.
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
      try HookSettingsFile.write(removing(from: try HookSettingsFile.read(file)), to: file)
    }
  }
}

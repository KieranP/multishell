extension AgentHookIntegration {
  /// The hooks as the file spells them: the whole file for one of ours, the
  /// object to merge for a file of the user's.
  func hooksObject(helper: String) -> [String: Any] {
    switch format {
    case .userSettingsFile:
      return ["hooks": ourGroups(helper: helper)]

    case .ownHookFile:
      var hooks: [String: Any] = [:]
      for event in writtenEvents { hooks[event.name] = [handler(event, helper: helper)] }
      return ["version": 1, "hooks": hooks]

    case .plugin:
      return [:]

    case .namedHookSet(let name):
      return [name: ourGroups(helper: helper).merging(["enabled": true]) { group, _ in group }]
    }
  }

  /// Each event's one group of ours, as a file the user keeps spells it.
  private func ourGroups(helper: String) -> [String: Any] {
    var groups: [String: Any] = [:]
    for event in writtenEvents { groups[event.name] = [ourGroup(for: event, helper: helper)] }
    return groups
  }

  /// What the settings window shows and the clipboard gets.
  public func snippet(helper: String = AgentHookCatalogue.helperReference) -> String {
    switch format {
    case .plugin: OpenCodePlugin.source(helper: helper)

    case .userSettingsFile, .ownHookFile, .namedHookSet:
      AgentHookFile.render(hooksObject(helper: helper))
    }
  }

  /// A matcher goes on the group, where the file has groups, and on the
  /// hook itself where it does not. Antigravity groups only its tool events.
  func ourGroup(for event: AgentHookEvent, helper: String) -> [String: Any] {
    if isNamedHookSet, event.matcher == nil { return handler(event, helper: helper) }
    var group: [String: Any] = ["hooks": [handler(event, helper: helper)]]
    if let matcher = event.matcher { group["matcher"] = matcher }
    return group
  }

  private func handler(_ event: AgentHookEvent, helper: String) -> [String: Any] {
    let namedEvent = payloadSpelling.hookLineNamesEvent ? event.name : nil
    var handler: [String: Any] = [
      "type": "command",
      "command": AgentHookCatalogue.command(agent: id, helper: helper, event: namedEvent),
    ]
    let timeout = event.timeoutSeconds ?? AgentHookCatalogue.timeoutSeconds
    switch format {
    case .userSettingsFile(let timeoutIsInMilliseconds):
      handler["timeout"] = timeoutIsInMilliseconds ? timeout * 1000 : timeout

    case .ownHookFile:
      handler["timeoutSec"] = timeout
      if let matcher = event.matcher { handler["matcher"] = matcher }

    case .namedHookSet:
      handler["timeout"] = timeout

    case .plugin:
      break
    }
    return handler
  }
}

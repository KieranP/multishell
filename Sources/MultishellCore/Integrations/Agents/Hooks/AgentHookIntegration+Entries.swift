extension AgentHookIntegration {
  /// The hooks as the file spells them: the whole file for one of ours, the
  /// object to merge for a file of the user's.
  func hooksObject(helper: String) -> [String: Any] {
    switch format {
    case .userSettingsFile:
      var hooks: [String: Any] = [:]
      for event in events { hooks[event.name] = [ourGroup(for: event, helper: helper)] }
      return ["hooks": hooks]
    case .ownHookFile:
      var hooks: [String: Any] = [:]
      for event in events { hooks[event.name] = [handler(event, helper: helper)] }
      return ["version": 1, "hooks": hooks]
    case .plugin:
      return [:]
    }
  }

  /// What the settings window shows and the clipboard gets.
  public func snippet(helper: String = AgentHookCatalogue.helperReference) -> String {
    switch format {
    case .plugin: OpenCodePlugin.source(helper: helper)
    case .userSettingsFile, .ownHookFile: AgentSettingsFile.render(hooksObject(helper: helper))
    }
  }

  /// A matcher goes on the group, where the file has groups, and on the
  /// hook itself where it does not.
  func ourGroup(for event: AgentHookEvent, helper: String) -> [String: Any] {
    var group: [String: Any] = ["hooks": [handler(event, helper: helper)]]
    if let matcher = event.matcher { group["matcher"] = matcher }
    return group
  }

  private func handler(_ event: AgentHookEvent, helper: String) -> [String: Any] {
    var handler: [String: Any] = [
      "type": "command", "command": AgentHookCatalogue.command(agent: id, helper: helper),
    ]
    let timeout = event.timeoutSeconds ?? AgentHookCatalogue.timeoutSeconds
    switch format {
    case .userSettingsFile(let timeoutIsInMilliseconds):
      handler["timeout"] = timeoutIsInMilliseconds ? timeout * 1000 : timeout
    case .ownHookFile:
      handler["timeoutSec"] = timeout
      if let matcher = event.matcher { handler["matcher"] = matcher }
    case .plugin:
      break
    }
    return handler
  }
}

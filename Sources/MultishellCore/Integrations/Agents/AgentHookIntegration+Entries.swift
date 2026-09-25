extension AgentHookIntegration {
  /// The hooks as the file spells them: the whole file for one of ours, the
  /// object to merge for a file of the user's.
  func entries(helper: String = AgentHookCatalogue.helperReference) -> [String: Any] {
    switch format {
    case .sharedSettings:
      var hooks: [String: Any] = [:]
      for event in events { hooks[event.name] = [group(event, helper: helper)] }
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
    case .sharedSettings, .ownHookFile: AgentSettingsFile.render(entries(helper: helper))
    }
  }

  /// A matcher goes on the group, where the file has groups, and on the
  /// hook itself where it does not.
  func group(_ event: AgentHookEvent, helper: String) -> [String: Any] {
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
    case .sharedSettings(let millisecondTimeout):
      handler["timeout"] = millisecondTimeout ? timeout * 1000 : timeout
    case .ownHookFile:
      handler["timeoutSec"] = timeout
      if let matcher = event.matcher { handler["matcher"] = matcher }
    case .plugin:
      break
    }
    return handler
  }
}

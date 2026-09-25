import Foundation

/// Whether an installed file holds what this build writes. Nothing rewrites
/// one unasked, the row offering Update instead; see Docs/design/agents.md.
extension AgentHookIntegration {
  public enum Installation: Sendable, Equatable {
    case absent, stale, current
  }

  /// `isInstalled` and `isCurrent` from one read of the file, for a status
  /// that asks both of every agent on the main actor.
  public func installation(
    in file: URL? = nil, helper: String = AgentHookCatalogue.helperReference
  ) -> Installation {
    let file = file ?? self.file
    if format.isOursAlone {
      guard let contents = ownFileText(file) else { return .absent }
      return contents == snippet(helper: helper) ? .current : .stale
    }
    // Any of ours, not one under every event: an older build's file lacks the
    // events added since, and that is the update this is here to offer.
    guard let settings = try? AgentSettingsFile.read(file), holdsAnyOfOurs(settings) else {
      return .absent
    }
    return isCurrent(in: settings, helper: helper) ? .current : .stale
  }

  /// Our groups under each event are exactly the one this build writes, and
  /// none is under an event it no longer asks for.
  func isCurrent(in settings: [String: Any], helper: String) -> Bool {
    guard let hooks = settings["hooks"] as? [String: Any],
      let wanted = entries(helper: helper)["hooks"] as? [String: Any]
    else { return false }
    // Rendered, as a file's numbers are read as marked literals.
    return Set(hooks.keys).union(wanted.keys).allSatisfy { event in
      let ours = ((hooks[event] as? [[String: Any]]) ?? []).filter(isMultishellGroup)
      let theirs = (wanted[event] as? [[String: Any]]) ?? []
      return AgentSettingsFile.render(["hooks": ours])
        == AgentSettingsFile.render(["hooks": theirs])
    }
  }
}

import Foundation

/// Putting an agent's hooks into its file on disk and taking them out again;
/// the merging itself is in `+Merging`. See Docs/design/agents.md.
extension AgentHookIntegration {
  func isInstalled(in file: URL? = nil) -> Bool {
    let file = file ?? self.file
    if format.isOursAlone { return ownFileText(file) != nil }
    guard let settings = try? AgentSettingsFile.read(file) else { return false }
    return isInstalled(in: settings)
  }

  public func install(
    into file: URL? = nil, helper: String = AgentHookCatalogue.helperReference
  ) throws {
    let file = file ?? self.file
    if format.isOursAlone {
      try AgentSettingsFile.writeOurs(snippet(helper: helper), to: file)
    } else {
      let settings = try AgentSettingsFile.read(file)
      guard hooksSection(settings) != nil else { throw UnreadableHookSection(file: file) }
      if let event = unreadableEvents(in: settings).first {
        throw UnreadableHookEntries(file: file, event: event)
      }
      // Ours out first, so an install over an older build's is an update.
      try AgentSettingsFile.write(adding(to: removing(from: settings), helper: helper), to: file)
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
      let settings = try AgentSettingsFile.read(file)
      guard holdsAnyOfOurs(settings) else { return }
      try AgentSettingsFile.write(removing(from: settings), to: file)
    }
  }

  /// A file that is ours alone, `nil` where it is absent or names no helper.
  func ownFileText(_ file: URL) -> String? {
    guard let contents = try? String(contentsOf: file, encoding: .utf8),
      contents.contains(AgentHookCatalogue.helperName)
    else { return nil }
    return contents
  }
}

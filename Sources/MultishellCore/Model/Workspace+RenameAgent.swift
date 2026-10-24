extension Workspace {
  /// The chosen Rename agent's run, `nil` while the default agent is chosen
  /// or the id is one this build does not know.
  public var renameOneShot: AgentOneShot? {
    renameAgentID.flatMap { AgentCatalogue.agent($0) }?.oneShot
  }
}

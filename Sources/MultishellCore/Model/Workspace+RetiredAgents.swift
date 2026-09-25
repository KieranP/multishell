extension Workspace {
  /// A stored id of a dropped agent raised an install alert every run, so it is
  /// forgotten on load: a tab restores as a plain shell, a preference falls back.
  mutating func forgetRetiredAgents() {
    let retired = AgentCatalogue.retiredIDs
    for index in sessions.indices where sessions[index].agentID.map(retired.contains) == true {
      sessions[index].agentID = nil
      sessions[index].title = ""
    }
    if preferredAgentID.map(retired.contains) == true { preferredAgentID = nil }
    for index in projects.indices
    where projects[index].settings.preferredAgentID.map(retired.contains) == true {
      projects[index].settings.preferredAgentID = nil
    }
  }
}

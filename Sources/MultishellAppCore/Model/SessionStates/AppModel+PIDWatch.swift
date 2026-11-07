import MultishellCore
import MultishellProcess

extension AppModel {
  /// The pids worth a poll: those a state is about always, and those an
  /// agent reported under only while the board is up; see agents/board-and-pane-rows.md.
  var watchedPIDs: Set<Int32> {
    guard showsAgentBoard else { return sessionStates.trackedPIDs }
    return sessionStates.trackedPIDs.union(reportedAgents.values.compactMap(\.pid))
  }

  /// An agent killed with Ctrl+C sends no Stop hook, so a named pid is
  /// polled and its state dropped once gone. No timeout.
  func updatePIDWatch() {
    guard !watchedPIDs.isEmpty else {
      pidWatch?.cancel()
      pidWatch = nil
      return
    }
    guard pidWatch == nil else { return }
    pidWatch = Task { @MainActor [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: self?.pidPollInterval ?? .zero)
        guard let self, !Task.isCancelled else { return }
        sweepGonePIDs()
        if watchedPIDs.isEmpty {
          pidWatch = nil
          return
        }
      }
    }
  }

  /// One pass over them. A state whose process has gone loses the claim it
  /// was making; a pane whose agent has gone is a plain shell again.
  func sweepGonePIDs() {
    let gone = watchedPIDs.filter(KernelProcessTable.isGone)
    for pid in gone {
      let heldAgents = sessionStates.programAgents(heldBy: pid)
      mutateStates { $0.noteProcessGone(pid) }
      forgetReportedAgents(withPID: pid)
      // A wrapper's pid stood for the hold, so the agent's own entry names another.
      var forgotAny = false
      for (id, agentID) in heldAgents where forgetReportedAgent(in: id, ifItIs: agentID) {
        forgotAny = true
      }
      if forgotAny { updateDockBadge() }
    }
    // Agents first: a shell swept before its dead agent announced a Done.
    for pid in gone {
      for ending in sessionStates.endings(ofShell: pid) {
        apply(
          SessionStateReport(state: .running, worker: ending.report),
          pid: nil,
          to: ending.key,
        )
      }
    }
  }

  private func forgetReportedAgents(withPID pid: Int32) {
    let gone = Set(reportedAgents.filter { $0.value.pid == pid }.keys)
    guard !gone.isEmpty else { return }
    // The directories they gave go with them; one write for the whole sweep.
    reportedAgentDirectories = reportedAgentDirectories.filter { !gone.contains($0.key) }
    setIfChanged(\.reportedAgents, reportedAgents.filter { !gone.contains($0.key) })
    updateDockBadge()
  }
}

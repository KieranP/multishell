import MultishellCore
import MultishellProcess

extension AppModel {
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
        guard let self else { return }
        try? await Task.sleep(for: pidPollInterval)
        guard !Task.isCancelled else { return }
        sweepGonePIDs()
        if watchedPIDs.isEmpty {
          pidWatch = nil
          return
        }
      }
    }
  }

  /// The pids worth a poll: those a state is about always, and those an
  /// agent reported under only while the board is up; see agents.md.
  var watchedPIDs: Set<Int32> {
    guard showsAgentBoard else { return sessionStates.trackedPIDs }
    return sessionStates.trackedPIDs.union(reportedAgents.values.compactMap(\.pid))
  }

  /// One pass over them. A state whose process has gone loses the claim it
  /// was making; a pane whose agent has gone is a plain shell again.
  func sweepGonePIDs() {
    let gone = watchedPIDs.filter(KernelProcessTable.isGone)
    for pid in gone {
      mutateStates { $0.processGone(pid) }
      dropReportedAgents(withPID: pid)
    }
    // Agents first: a shell swept before its dead agent announced a Done.
    for pid in gone {
      for ending in sessionStates.endings(ofShell: pid) {
        apply(
          SessionStateReport(state: .running, subagent: ending.report), pid: nil, to: ending.key)
      }
    }
  }

  private func dropReportedAgents(withPID pid: Int32) {
    guard setIfChanged(\.reportedAgents, reportedAgents.filter { $0.value.pid != pid }) else {
      return
    }
    updateDockBadge()
  }
}

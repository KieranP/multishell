import Foundation
import MultishellCore

extension AppModel {
  /// A program's own OSC 7501 report about a live pane. The agent it is
  /// stays with the hold; see Docs/design/agents/program-status.md.
  func noteProgramStatus(_ status: ProgramStatus, from pid: Int32?, in id: TerminalSession.ID) {
    guard liveSessionIDs.contains(id) else { return }
    let key = SessionStates.Key.session(id)
    let agentBefore = sessionStates.programAgent(key)
    applyAndNotify(to: key, isSilent: false) { states, isSeen in
      states.apply(programStatus: status, pid: pid, for: key, isSeen: isSeen, at: Date())
    }
    if let agentBefore, !sessionStates.isHeldByProgram(key),
      forgetReportedAgent(in: id, ifItIs: agentBefore.id)
    {
      updateDockBadge()
    }
    updatePIDWatch()
  }
}

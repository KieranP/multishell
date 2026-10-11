import Foundation
import MultishellCore

extension AppModel {
  func replyToInfo() -> ControlReply {
    .json(
      AppInfo(
        pid: ProcessInfo.processInfo.processIdentifier,
        stateFile: Paths.stateFile.path,
        socket: Paths.socketFile.path,
        areDebugToolsEnabled: areDebugToolsEnabled,
        windows: platform.windows,
        presented: presentations,
      )
    )
  }

  /// A turn later, so the answer is on its way first; the helper waits for
  /// the socket to go rather than for the answer.
  func replyToQuit(force: Bool) -> ControlReply {
    if refusesOverWorkingAgent(in: workspace.sessions.map(\.id), force: force) {
      return .refused(.agentWorking)
    }
    Task {
      // `terminate` returns only where the app goes on, and the next Cmd+Q asks.
      quitsWithoutAsking = true
      platform.quit()
      quitsWithoutAsking = false
    }
    return .done
  }
}

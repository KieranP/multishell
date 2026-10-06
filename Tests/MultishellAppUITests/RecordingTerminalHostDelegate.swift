import MultishellCore

@MainActor
final class RecordingTerminalHostDelegate: TerminalHostDelegate {
  private(set) var reports: [TerminalSession.ID] = []

  func terminalHost(_ host: any TerminalHost, didRetitle id: TerminalSession.ID, to title: String) {
    reports.append(id)
  }
  func terminalHost(_ host: any TerminalHost, didExit id: TerminalSession.ID) { reports.append(id) }
  func terminalHost(_ host: any TerminalHost, didAskToClose id: TerminalSession.ID) {
    reports.append(id)
  }
  func terminalHost(_ host: any TerminalHost, didSeeActivityIn id: TerminalSession.ID) {
    reports.append(id)
  }
  func terminalHost(_ host: any TerminalHost, didFocus id: TerminalSession.ID) {
    reports.append(id)
  }
}

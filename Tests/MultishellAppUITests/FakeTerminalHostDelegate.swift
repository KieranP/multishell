import Foundation
import MultishellCore

@MainActor
final class FakeTerminalHostDelegate: TerminalHostDelegate {
  private(set) var reports: [TerminalSession.ID] = []
  private(set) var editedFiles: [URL] = []
  private(set) var pastedFiles: [(files: [URL], id: TerminalSession.ID)] = []
  var textForPastedFiles: String?

  func terminalHost(_ host: any TerminalHost, didRetitle id: TerminalSession.ID, to title: String) {
    reports.append(id)
  }
  func terminalHost(_ host: any TerminalHost, didExit id: TerminalSession.ID) { reports.append(id) }
  func terminalHost(_ host: any TerminalHost, didAskToClose id: TerminalSession.ID) {
    reports.append(id)
  }
  func terminalHost(_ host: any TerminalHost, didAskToEdit file: URL, in id: TerminalSession.ID) {
    reports.append(id)
    editedFiles.append(file)
  }
  func terminalHost(
    _ host: any TerminalHost,
    textForPastedFiles urls: [URL],
    in id: TerminalSession.ID,
  ) -> String? {
    pastedFiles.append((urls, id))
    return textForPastedFiles
  }
  func terminalHost(_ host: any TerminalHost, didSeeActivityIn id: TerminalSession.ID) {
    reports.append(id)
  }
  func terminalHost(_ host: any TerminalHost, didFocus id: TerminalSession.ID) {
    reports.append(id)
  }
  func terminalHost(
    _ host: any TerminalHost,
    didFinishCommandIn id: TerminalSession.ID,
    exitCode: Int32?,
  ) {
    reports.append(id)
  }
  func terminalHost(
    _ host: any TerminalHost,
    didCount count: TerminalSearchCount,
    in id: TerminalSession.ID,
  ) {}
}

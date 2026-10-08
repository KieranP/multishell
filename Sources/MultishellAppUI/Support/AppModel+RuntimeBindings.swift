import MultishellAppCore
import MultishellCore
import SwiftUI

/// Bindings for what the model holds for this run, which the workspace does
/// not save: the board's filter, the debug tools' toggles and a find bar's text.
extension AppModel {
  var showsAllTerminalsBinding: Binding<Bool> {
    Binding(get: { self.showsAllTerminals }, set: { self.setShowsAllTerminals($0) })
  }

  var debugToolsEnabledBinding: Binding<Bool> {
    Binding(get: { self.areDebugToolsEnabled }, set: { self.setDebugToolsEnabled($0) })
  }

  var debugPausedBinding: Binding<Bool> {
    Binding(get: { self.isDebugPaused }, set: { self.setDebugPaused($0) })
  }

  func findTextBinding(of sessionID: TerminalSession.ID) -> Binding<String> {
    Binding(get: { self.findText(of: sessionID) }, set: { self.setFindText($0, of: sessionID) })
  }
}

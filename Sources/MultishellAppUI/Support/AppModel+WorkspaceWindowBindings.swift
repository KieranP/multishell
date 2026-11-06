import MultishellAppCore
import MultishellCore
import SwiftUI

/// Bindings over the model's own setters, for toggles and fields the menus and
/// views flip: the board's filter, the Files panel, the debug toggles, find text.
extension AppModel {
  var showsAllTerminalsBinding: Binding<Bool> {
    Binding(get: { self.showsAllTerminals }, set: { self.setShowsAllTerminals($0) })
  }

  var debugToolsEnabledBinding: Binding<Bool> {
    Binding(get: { self.areDebugToolsEnabled }, set: { self.setDebugToolsEnabled($0) })
  }

  var showsFilesPanelBinding: Binding<Bool> {
    Binding(get: { self.showsFilesPanel }, set: { self.setShowsFilesPanel($0) })
  }

  var debugPausedBinding: Binding<Bool> {
    Binding(get: { self.isDebugPaused }, set: { self.setDebugPaused($0) })
  }

  func findTextBinding(of targetID: FindTargetID) -> Binding<String> {
    Binding(get: { self.findText(of: targetID) }, set: { self.setFindText($0, of: targetID) })
  }
}

import MultishellAppCore
import SwiftUI

/// Bindings for the toggles the model holds for this run, which the workspace
/// does not save: the board's filter and the debug tools'.
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
}

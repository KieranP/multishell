import MultishellAppCore
import SwiftUI

/// Hands the scenes' window openers to the platform: a command-line request has
/// no view to call them from, and AppKit cannot open a SwiftUI scene.
struct WindowOpenerRegistrationModifier: ViewModifier {
  let platform: MacPlatform
  @Environment(\.openSettings) private var openSettings

  func body(content: Content) -> some View {
    content.onAppear {
      platform.openAuxiliaryWindow = { [openSettings] window in
        switch window {
        case .settings: openSettings()
        }
      }
    }
  }
}

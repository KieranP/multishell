import SwiftUI

extension View {
  func registeringWindowOpeners(with platform: MacPlatform) -> some View {
    modifier(WindowOpenerRegistrationModifier(platform: platform))
  }
}

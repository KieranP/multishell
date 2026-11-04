import MultishellAppCore
import MultishellCore
import SwiftUI

/// A tab's colours in its strip beyond its section's own.
extension Theme {
  /// The strip's fill where `TabHoverWash` washes the tab; `nil` is no wash.
  func hoverWashRGB(onShownTab isShown: Bool, isHovered: Bool) -> RGB? {
    TabHoverWash.isWashed(onShownTab: isShown, isHovered: isHovered)
      ? interfaceRGB(.fill, in: .tabBar) : nil
  }

  func hoverWash(onShownTab isShown: Bool, isHovered: Bool) -> Color? {
    hoverWashRGB(onShownTab: isShown, isHovered: isHovered)?.color
  }
}

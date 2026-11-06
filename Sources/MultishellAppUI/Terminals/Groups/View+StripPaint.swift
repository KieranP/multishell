import SwiftUI

extension View {
  /// Paints behind a strip part short of the strip's bottom hairline, which
  /// runs under every part but the shown tab. See tabs-and-groups/tab-strip.md.
  func stripPaint(_ color: Color) -> some View {
    background(color.padding(.bottom, UIMetrics.hairlineThickness))
  }
}

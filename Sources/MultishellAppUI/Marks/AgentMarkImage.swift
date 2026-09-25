import MultishellCore
import SwiftUI

/// An agent's mark as an `Image`, for the one place a drawn view will not do:
/// an AppKit menu, which takes a title and an image and nothing else.
@MainActor
enum AgentMarkImage {
  /// Sized against a menu title, not a tab: the marks run to the edges of
  /// their square, so 15 drew larger than the items read for.
  private static let size: Double = 13

  /// Keyed by the scale it was drawn at too: a window moved to a display of
  /// another one keeps the marks it rendered, and they would be soft there.
  private static var rendered: [Key: Image] = [:]

  private struct Key: Hashable {
    let agentID: String
    let scale: CGFloat
  }

  /// A mark with a colour of its own keeps it; the rest are templates, which
  /// the menu tints itself.
  static func image(for agentID: String) -> Image? {
    let key = Key(agentID: agentID, scale: NSScreen.main?.backingScaleFactor ?? 2)
    if let cached = rendered[key] { return cached }
    let tint = AgentCatalogue.markTintRGB(agentID)
    let renderer = ImageRenderer(
      content: AgentMarkView(
        agentID: agentID, plainTint: .black, size: size))
    renderer.scale = key.scale
    guard let nsImage = renderer.nsImage else { return nil }
    nsImage.isTemplate = tint == nil
    let image = Image(nsImage: nsImage)
    rendered[key] = image
    return image
  }
}

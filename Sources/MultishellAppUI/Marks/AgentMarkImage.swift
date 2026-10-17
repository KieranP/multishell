import MultishellAppCore
import MultishellCore
import SwiftUI

/// An agent's mark or the shell's glyph as an `Image`, for where a view won't do:
/// an AppKit menu, which takes a title and an image and nothing else.
@MainActor
enum AgentMarkImage {
  private struct Key: Hashable {
    let agentID: String?
    let tint: RGB?
    let scale: CGFloat
  }

  /// Sized against a menu title, not a tab: the marks run to the edges of
  /// their square, so 15 drew larger than the items read for.
  private static let size: Double = 13

  /// Keyed by the scale it was drawn at too: a window moved to a display of
  /// another one keeps the marks it rendered, and they would be soft there.
  private static var rendered: [Key: Image] = [:]

  /// A mark with a colour of its own keeps it; the rest are templates, which
  /// the menu tints itself. `nil` is the shell's terminal glyph.
  static func image(for agentID: String?, tint: RGB?) -> Image? {
    let key = Key(agentID: agentID, tint: tint, scale: NSScreen.mainBackingScale)
    if let cached = rendered[key] { return cached }
    guard let nsImage = nsImage(for: agentID, tint: tint, scale: key.scale) else { return nil }
    let image = Image(nsImage: nsImage)
    rendered[key] = image
    return image
  }

  static func nsImage(for agentID: String?, tint: RGB?, scale: CGFloat) -> NSImage? {
    let renderer = ImageRenderer(content: content(for: agentID, tint: tint))
    renderer.scale = scale
    guard let nsImage = renderer.nsImage else { return nil }
    nsImage.isTemplate = tint == nil
    return nsImage
  }

  /// The terminal glyph is wider than the square, which a tab lets it spill
  /// past but the renderer clips to, so here it is scaled to fit.
  @ViewBuilder
  private static func content(for agentID: String?, tint: RGB?) -> some View {
    if let agentID {
      AgentMarkView(agentID: agentID, markTint: tint, plainTint: .black, size: size)
    } else {
      Image(systemName: PaneSymbol.terminal)
        .resizable()
        .scaledToFit()
        .foregroundStyle(.black)
        .frame(width: size, height: size)
    }
  }
}

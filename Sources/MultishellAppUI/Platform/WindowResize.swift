import CoreGraphics

/// Where `window size` puts the main window: its top edge kept and its least
/// size held, as a drag of the bottom corner keeps them, and on its screen.
enum WindowResize {
  /// `setFrame` keeps no frame on screen, so a size past the screen is cut to
  /// it and a frame running off it slides back.
  static func frame(
    resizing frame: CGRect,
    to size: CGSize,
    minimum: CGSize,
    within visible: CGRect?,
  ) -> CGRect {
    var width = max(size.width, minimum.width)
    var height = max(size.height, minimum.height)
    guard let visible else {
      return CGRect(x: frame.minX, y: frame.maxY - height, width: width, height: height)
    }
    width = min(width, max(visible.width, minimum.width))
    height = min(height, max(visible.height, minimum.height))
    let x = max(min(frame.minX, visible.maxX - width), visible.minX)
    let y = max(min(frame.maxY - height, visible.maxY - height), visible.minY)
    return CGRect(x: x, y: y, width: width, height: height)
  }
}

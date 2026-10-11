import AppKit
import CoreImage

/// A view drawn into a PNG, needing no Screen Recording grant: Ghostty's surfaces
/// first, then AppKit's cached view over them, clear there; agents.md.
@MainActor
enum ViewScreenshot {
  static func png(of view: NSView) -> Data? {
    let bounds = view.bounds
    guard bounds.width > 0, bounds.height > 0,
      let cached = view.bitmapImageRepForCachingDisplay(in: bounds),
      let composed = view.bitmapImageRepForCachingDisplay(in: bounds),
      let context = NSGraphicsContext(bitmapImageRep: composed)
    else { return nil }
    view.cacheDisplay(in: bounds, to: cached)
    let drawer = CIContext(cgContext: context.cgContext, options: nil)
    let scale = view.window?.backingScaleFactor ?? 1
    for (surface, frame) in surfaces(under: view, in: view) {
      let image = CIImage(ioSurface: surface)
      context.cgContext.saveGState()
      context.cgContext.clip(to: frame)
      drawer.draw(
        image,
        in: place(surfaceOfPixels: image.extent.size, scale: scale, in: frame),
        from: image.extent,
      )
      context.cgContext.restoreGState()
    }
    if let image = cached.cgImage {
      context.cgContext.draw(image, in: CGRect(origin: .zero, size: bounds.size))
    }
    context.flushGraphics()
    return composed.representation(using: .png, properties: [:])
  }

  /// Its own size from the frame's top left, as the layer's top-left gravity
  /// shows it, a surface not yet resized spilling past the frame to be clipped.
  static func place(surfaceOfPixels pixels: CGSize, scale: CGFloat, in frame: CGRect) -> CGRect {
    let size = CGSize(width: pixels.width / scale, height: pixels.height / scale)
    return CGRect(
      x: frame.minX,
      y: frame.maxY - size.height,
      width: size.width,
      height: size.height,
    )
  }

  /// Each IOSurface `view` and those under it show, with its frame in
  /// `root`'s bitmap, whose origin is bottom left whichever way `root` is flipped.
  private static func surfaces(under view: NSView, in root: NSView) -> [(IOSurfaceRef, CGRect)] {
    var found: [(IOSurfaceRef, CGRect)] = []
    if let contents = view.layer?.contents as CFTypeRef?,
      CFGetTypeID(contents) == IOSurfaceGetTypeID()
    {
      var frame = view.convert(view.bounds, to: root)
      if root.isFlipped { frame.origin.y = root.bounds.height - frame.maxY }
      found.append((unsafeDowncast(contents, to: IOSurfaceRef.self), frame))
    }
    for subview in view.subviews where !subview.isHidden {
      found += surfaces(under: subview, in: root)
    }
    return found
  }
}

import AppKit
import SwiftUI

/// A window never ordered in, which lays a view out and draws it without asking for anything.
@MainActor
enum OffscreenWindow {
  /// `rect` defaults to the content's own frame.
  static func holding(_ content: NSView, rect: NSRect? = nil, deferred: Bool = true) -> NSWindow {
    let window = NSWindow(
      contentRect: rect ?? content.frame, styleMask: [.titled], backing: .buffered,
      defer: deferred)
    window.contentView = content
    content.layoutSubtreeIfNeeded()
    return window
  }

  /// `run(until:)` returns at once while the main run loop has no source, so the wait is
  /// looped, until `done` or `limit`.
  static func settle(until done: () -> Bool = { false }, within limit: TimeInterval) {
    let deadline = Date().addingTimeInterval(limit)
    while !done(), Date() < deadline {
      RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01))
    }
  }

  /// The width `content` takes unconstrained, hosted in a window held for the read.
  static func naturalWidth(of content: some View, windowSize: CGSize) -> Double {
    let host = NSHostingView(rootView: content.fixedSize())
    let window = holding(host, rect: NSRect(origin: .zero, size: windowSize), deferred: false)
    return withExtendedLifetime(window) { host.fittingSize.width }
  }

  /// What `view` draws, at the backing scale, or `nil` where AppKit gives no bitmap.
  static func pixels(of view: NSView) -> NSBitmapImageRep? {
    guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
    view.cacheDisplay(in: view.bounds, to: bitmap)
    return bitmap
  }

  /// What `content` draws hosted at `size`, in a window held for the read.
  static func pixels(ofHosted content: some View, size: CGSize) -> NSBitmapImageRep? {
    let host = NSHostingView(rootView: content)
    host.frame = NSRect(origin: .zero, size: size)
    let window = holding(host, deferred: false)
    return withExtendedLifetime(window) { pixels(of: host) }
  }
}

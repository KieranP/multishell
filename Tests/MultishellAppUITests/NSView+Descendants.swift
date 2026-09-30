import AppKit

extension NSView {
  /// This view and every view under it of that type, depth first.
  func descendants<Found: NSView>(of type: Found.Type) -> [Found] {
    let own = (self as? Found).map { [$0] } ?? []
    return own + subviews.flatMap { $0.descendants(of: type) }
  }
}

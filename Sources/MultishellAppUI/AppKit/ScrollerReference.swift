import AppKit

/// How the two halves of a sideways wheel find each other; SwiftUI flattens
/// the tree, so the catcher cannot look. See Docs/design/tabs-and-columns.md.
final class ScrollerReference {
  weak var scroller: NSScrollView?
}

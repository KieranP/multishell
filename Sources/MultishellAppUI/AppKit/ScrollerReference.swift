import AppKit

/// How the two halves of a sideways wheel find each other; SwiftUI flattens
/// the tree, so the catcher cannot look. See Docs/design/tabs-and-groups/tab-strip.md.
final class ScrollerReference {
  weak var scroller: NSScrollView?
}

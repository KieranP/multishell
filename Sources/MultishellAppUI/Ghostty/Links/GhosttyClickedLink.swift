import Foundation

/// A link Cmd+clicked in a pane: its text, or an OSC 8 link's target, and the
/// directory a relative one resolves in at that moment.
struct GhosttyClickedLink: Hashable, Sendable {
  let text: String
  let directory: URL
  let isHyperlink: Bool
}

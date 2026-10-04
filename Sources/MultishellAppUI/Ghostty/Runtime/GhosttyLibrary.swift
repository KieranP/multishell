import Foundation
import GhosttyKit

/// libghostty's process-wide setup, which any config or app needs first.
enum GhosttyLibrary {
  private static let initialized: Void = {
    // Named, a release build taking an inherited value over the bundle. Not in
    // a test process: it has no terminfo, and setenv races its shell threads.
    if Bundle.main.bundleURL.pathExtension == "app", let resources = Bundle.main.resourceURL {
      setenv("GHOSTTY_RESOURCES_DIR", resources.appendingPathComponent("ghostty").path, 1)
    }
    // The arguments are for Ghostty's own CLI actions, which an embedder has none of.
    precondition(ghostty_init(0, nil) == GHOSTTY_SUCCESS, "libghostty failed to initialise")
  }()

  static func initialize() {
    _ = initialized
  }
}

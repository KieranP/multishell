import Foundation

/// The helper's and the app's directories inside the bundle, which lead a pane's PATH.
public struct BundleDirectories: Sendable {
  let helper: URL
  let app: URL

  public init(helper: URL, app: URL) {
    self.helper = helper
    self.app = app
  }
}

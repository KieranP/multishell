import Foundation

extension URL {
  /// Itself where it is a web page a host linked; any other scheme is never opened.
  var asWebPage: URL? {
    ["http", "https"].contains(scheme?.lowercased()) ? self : nil
  }
}

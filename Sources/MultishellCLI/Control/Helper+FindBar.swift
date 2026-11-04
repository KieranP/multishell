extension Helper {
  /// The `find` a pane's or file tab's answer prints, `nil` while its bar is down.
  static func findBar(in details: String?) -> [String: Any]? {
    (jsonValue(details) as? [String: Any])?["find"] as? [String: Any]
  }
}

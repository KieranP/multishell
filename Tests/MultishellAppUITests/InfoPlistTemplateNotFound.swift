/// Thrown rather than returning empty, so a different checkout layout fails naming where it
/// looked instead of passing on an empty string.
struct InfoPlistTemplateNotFound: Error, CustomStringConvertible {
  let path: String
  var description: String { "Info.plist.in not found at \(path)" }
}

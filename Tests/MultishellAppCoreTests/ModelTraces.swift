@testable import MultishellAppCore

/// Every string an `AppModel`'s stored fields hold that names one of `paths`.
@MainActor
enum ModelTraces {
  static func find(
    _ paths: Set<String>,
    in model: AppModel<FakeSurface>,
    exempting exempt: Set<String>,
  ) -> [(field: String, value: String)] {
    var found: [(field: String, value: String)] = []
    for child in Mirror(reflecting: model).children {
      guard let label = child.label, !exempt.contains(label) else { continue }
      for hit in strings(in: child.value) where paths.contains(hit) {
        found.append((label, hit))
      }
    }
    return found
  }

  /// Classes are skipped, keeping out the store, reconciler and engine, which answer to the
  /// workspace. The depth bound only stops endless nesting; a cache buried deeper goes unchecked.
  private static func strings(in value: Any, depth: Int = 0) -> [String] {
    guard depth < 12 else { return [] }
    if let text = value as? String { return [text] }
    if let keyed = value as? [String: Any] {
      return Array(keyed.keys) + keyed.values.flatMap { strings(in: $0, depth: depth + 1) }
    }
    if let set = value as? Set<String> { return Array(set) }
    if let list = value as? [String] { return list }
    let mirror = Mirror(reflecting: value)
    switch mirror.displayStyle {
    case .struct, .enum, .optional, .tuple, .collection, .set, .dictionary:
      return mirror.children.flatMap { strings(in: $0.value, depth: depth + 1) }

    default:
      return []
    }
  }
}

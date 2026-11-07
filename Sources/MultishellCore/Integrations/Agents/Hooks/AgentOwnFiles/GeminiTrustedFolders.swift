import Foundation

/// Gemini's `trustedFolders.json`, its rules in file order: Gemini 0.66's
/// `isPathTrusted` takes the longest normalised path in UTF-16 units, the first on a tie.
struct GeminiTrustedFolders {
  private struct Rule {
    let path: String
    let level: String
  }

  private static let levels: Set = ["TRUST_FOLDER", "TRUST_PARENT", "DO_NOT_TRUST"]

  private let rules: [Rule]

  /// Comments allowed, as Gemini reads it; `nil` for no object of strings.
  init?(text: String) {
    let stripped = text.withoutJSONComments
    guard
      let object = try? JSONSerialization.jsonObject(with: Data(stripped.utf8))
        as? [String: String]
    else { return nil }
    let positions = Dictionary(
      uniqueKeysWithValues: object.keys.map { ($0, Self.position(of: $0, in: stripped)) }
    )
    let inFileOrder = object.filter { Self.levels.contains($0.value) }
      .sorted { positions[$0.key, default: .max] < positions[$1.key, default: .max] }
    // Gemini keys each rule by its normalised path: spellings of one folder become
    // one rule, in the first one's place, with the last one's level.
    var rules: [Rule] = []
    var placeOfPath: [String: Int] = [:]
    for (path, level) in inFileOrder {
      let normalised = Self.normalised(path)
      if let place = placeOfPath[normalised] {
        rules[place] = Rule(path: normalised, level: level)
      } else {
        placeOfPath[normalised] = rules.count
        rules.append(Rule(path: normalised, level: level))
      }
    }
    self.rules = rules
  }

  /// Gemini 0.66's `normalizePath`: absolute, then lowercased, macOS's names
  /// ignoring case.
  private static func normalised(_ path: String) -> String {
    URL(fileURLWithPath: path).standardized.path.lowercased()
  }

  /// Where `key` is written, so equal lengths keep the file's order a dictionary loses.
  private static func position(of key: String, in text: String) -> Int {
    guard
      let encoded = try? JSONSerialization.data(
        withJSONObject: key,
        options: [.fragmentsAllowed, .withoutEscapingSlashes],
      ),
      let found = text.range(of: String(decoding: encoded, as: UTF8.self))
    else { return .max }
    return found.lowerBound.utf16Offset(in: text)
  }

  private static func resolved(_ path: String) -> String {
    URL(fileURLWithPath: path).comparablePath
  }

  /// The longest rule covering `folder` decides, a parent rule standing for the
  /// folder above it; no rule is no trust.
  func trusts(_ folder: String) -> Bool {
    let target = URL(fileURLWithPath: Self.resolved(folder))
    var decisive: Rule?
    for rule in rules {
      let covered =
        rule.level == "TRUST_PARENT" ? (rule.path as NSString).deletingLastPathComponent : rule.path
      guard target.pathComponents(under: URL(fileURLWithPath: Self.resolved(covered))) != nil,
        rule.path.utf16.count > decisive?.path.utf16.count ?? -1
      else { continue }
      decisive = rule
    }
    return decisive.map { $0.level == "TRUST_FOLDER" || $0.level == "TRUST_PARENT" } ?? false
  }
}

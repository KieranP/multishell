import Foundation

extension SharedProjectSettings {
  public static func file(in repository: URL) -> URL {
    repository.appendingPathComponent(fileName, isDirectory: false)
  }

  /// The file's contents and the digest of its bytes, or `nil` when the
  /// repository has none. Throws for a file that is there but is not JSON.
  public static func load(from repository: URL) throws -> SharedProjectSettings? {
    let url = file(in: repository)
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    let data = try Data(contentsOf: url)
    var settings = try JSONDecoder().decode(SharedProjectSettings.self, from: data)
    settings.digest = FileDigest.sha256(of: data)
    return settings
  }

  /// These settings over what `existing` asks trust for and the keys this build
  /// could not read, neither being the user's to drop; see Docs/design/settings.md.
  public func carryingOver(from existing: SharedProjectSettings?) -> SharedProjectSettings {
    guard let existing else { return self }
    var kept = self
    for field in Self.trustCovered {
      kept[keyPath: field] = self[keyPath: field] ?? existing[keyPath: field]
    }
    kept.unrecognisedKeys = existing.unrecognisedKeys
    return kept
  }

  /// The file's bytes, sorted and indented so a diff reads well, and these settings
  /// as they will read back, digest set. The digest is known before the file is there.
  public func fileContents() throws -> (data: Data, settings: SharedProjectSettings) {
    let encoder = JSONEncoder.forFile()
    let fields = try fields()
    let kept = unrecognisedKeys.filter { fields[$0.key] == nil }
    let data = try encoder.encode(kept.merging(fields) { _, field in field })
    var written = self
    written.unrecognisedKeys = kept
    written.digest = FileDigest.sha256(of: data)
    return (data, written)
  }

  /// The fields as the file would carry them, blanks and unknowns left out.
  func fields() throws -> [String: JSONValue] {
    try JSONDecoder().decode([String: JSONValue].self, from: JSONEncoder().encode(self))
  }
}

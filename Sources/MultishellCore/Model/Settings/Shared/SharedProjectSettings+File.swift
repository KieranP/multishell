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
    settings.digest = HexDigest.sha256(of: data)
    return settings
  }

  /// These settings over what `existing` asks trust for and the keys this build
  /// could not read, neither being the user's to drop; see Docs/design/settings.md.
  public func carryingOver(from existing: SharedProjectSettings?) -> SharedProjectSettings {
    guard let existing else { return self }
    var kept = self
    for field in Self.trustCoveredFields {
      kept[keyPath: field] = self[keyPath: field] ?? existing[keyPath: field]
    }
    for start in Self.trustCoveredStarts {
      kept[keyPath: start] = self[keyPath: start] ?? existing[keyPath: start]
    }
    // Merged, not replaced: an untrusted file's actions are out of force, and
    // an own action would otherwise drop every one of a teammate's.
    let actions = ProjectAction.layered(own: actions ?? [], over: existing.actions ?? [])
    kept.actions = actions.isEmpty ? nil : actions
    kept.unrecognisedKeys = existing.unrecognisedKeys
    kept.actionEntriesAsWritten = existing.actionEntriesAsWritten
    return kept
  }

  /// Whether every word a yes covers in `merged`, these carried over a file,
  /// is these settings' own, whatever order the merge puts their actions in.
  public func ownsEverythingTrustCovers(in merged: SharedProjectSettings) -> Bool {
    // An action entry this build cannot read is a teammate's word a newer build runs.
    let own = Set((try? Self.entries(of: actions)) ?? [])
    guard let entries = try? merged.mergedActionEntries(), entries.allSatisfy(own.contains)
    else { return false }
    var reordered = self
    let names = Set(actions?.map(\.name) ?? [])
    reordered.actions = merged.actions?.filter { names.contains($0.name) }
    return merged.trustCoveredText == reordered.trustCoveredText
  }

  /// The file's bytes, sorted and indented so a diff reads well, and these settings
  /// as they will read back, digest set. The digest is known before the file is there.
  public func fileContents() throws -> (data: Data, settings: SharedProjectSettings) {
    let encoder = JSONEncoder.forFile()
    var fields = try fields()
    var written = self
    let actionsKey = CodingKeys.actions.stringValue
    if fields[actionsKey] != nil {
      let entries = try mergedActionEntries()
      fields[actionsKey] = .array(entries)
      written.actionEntriesAsWritten = try entries == Self.entries(of: actions) ? nil : entries
    }
    let kept = unrecognisedKeys.filter { fields[$0.key] == nil }
    let data = try encoder.encode(kept.merging(fields) { _, field in field })
    written.unrecognisedKeys = kept
    written.digest = HexDigest.sha256(of: data)
    return (data, written)
  }

  /// The fields as the file would carry them, blanks and unknowns left out.
  func fields() throws -> [String: JSONValue] {
    try JSONDecoder().decode([String: JSONValue].self, from: JSONEncoder().encode(self))
  }
}

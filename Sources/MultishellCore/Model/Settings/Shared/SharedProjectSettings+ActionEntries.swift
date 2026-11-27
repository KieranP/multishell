import Foundation

extension SharedProjectSettings {
  /// `actions` as the file carries them.
  static func entries(of actions: [ProjectAction]?) throws -> [JSONValue] {
    try JSONDecoder().decode([JSONValue].self, from: JSONEncoder().encode(actions ?? []))
  }

  /// Each action in `actions`' order, written over the file's entry of its name,
  /// then the entries this build cannot read: what it cannot read goes back as it was.
  func mergedActionEntries() throws -> [JSONValue] {
    let own = try Self.entries(of: actions)
    guard let written = actionEntriesAsWritten else { return own }
    let names = (actions ?? []).map(\.name)
    let known = Set(names)
    var writtenByName: [String: [String: JSONValue]] = [:]
    var unread: [JSONValue] = []
    for entry in written {
      guard case .object(let fields) = entry,
        case .string(let name)? = fields[ProjectAction.CodingKeys.name.stringValue],
        let trimmed = name.trimmedOfAllWhitespaceOrNil,
        known.contains(trimmed), writtenByName[trimmed] == nil
      else {
        unread.append(entry)
        continue
      }
      writtenByName[trimmed] = fields
    }
    let merged = zip(names, own).map { name, mine -> JSONValue in
      guard let fields = writtenByName[name], case .object(let mineFields) = mine else {
        return mine
      }
      return .object(fields.merging(mineFields) { _, mine in mine })
    }
    return merged + unread
  }
}

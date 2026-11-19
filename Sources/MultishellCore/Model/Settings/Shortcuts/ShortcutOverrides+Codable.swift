/// An object of command to keys, `"split-right": "cmd+backslash"`, blank for
/// none. A synthesised dictionary would be an array, and a nil `null`.
extension ShortcutOverrides: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: RawCodingKey.self)
    self.init()
    var held = Set(ShortcutCommand.allCases.filter(\.isFixed).map(\.defaultCombination))
    // Tolerated per entry, in `allCases` order: an unknown command, unreadable or
    // refused keys, or a claim on keys an earlier one holds costs that entry alone.
    for command in ShortcutCommand.changeable {
      guard
        let text = container.decodeTolerantly(
          String.self,
          forKey: RawCodingKey(stringValue: command.rawValue),
        )
      else { continue }
      guard let spelled = text.trimmedOfAllWhitespaceOrNil else {
        set(.noKeys, for: command)
        continue
      }
      guard let keys = KeyCombination(spelled: spelled), keys.refusal == nil,
        held.insert(keys).inserted
      else { continue }
      set(.keys(keys), for: command)
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: RawCodingKey.self)
    for command in ShortcutCommand.allCases {
      guard let override = self[command] else { continue }
      let text =
        switch override {
        case .keys(let keys): keys.spelled
        case .noKeys: ""
        }
      try container.encode(text, forKey: RawCodingKey(stringValue: command.rawValue))
    }
  }
}

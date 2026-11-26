/// An object of action name to keys, `"Start Server": "ctrl+alt+s"`, as
/// `ShortcutOverrides` spells them.
extension ActionShortcuts: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: RawCodingKey.self)
    self.init()
    // Tolerated per entry, in name order so a second claim on keys always
    // loses to the same one: unreadable or refused keys cost that entry alone.
    for key in container.allKeys.sorted(by: { $0.stringValue < $1.stringValue }) {
      guard let text = container.decodeTolerantly(String.self, forKey: key),
        let keys = KeyCombination(spelled: text), keys.refusal == nil,
        name(holding: keys) == nil
      else { continue }
      set(keys, for: key.stringValue)
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: RawCodingKey.self)
    for (name, keys) in entries {
      try container.encode(keys.spelled, forKey: RawCodingKey(stringValue: name))
    }
  }
}

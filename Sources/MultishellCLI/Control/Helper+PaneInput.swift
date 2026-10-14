import Foundation
import MultishellCore

extension Helper {
  static func typeIntoPane(
    _ id: UUID,
    _ text: String,
    _ optionWords: ArraySlice<String>,
    environment: [String: String],
  ) throws -> Int32 {
    let enter = try CommandOptions(
      optionWords,
      valued: [],
      flags: ["enter"],
      topic: ControlCommand.panes.rawValue,
    )
    .has("enter")
    return try ask(
      .typeIntoPane(id: id, text: text, pressingReturn: enter),
      environment: environment,
    )
  }

  static func pasteIntoPane(
    _ id: UUID,
    _ text: String,
    environment: [String: String],
  ) throws -> Int32 {
    try ask(.pasteIntoPane(id: id, text: text), environment: environment)
  }

  static func pressKeys(
    _ words: ArraySlice<String>,
    in id: UUID,
    environment: [String: String],
  ) throws -> Int32 {
    try ask(.pressKeys(id: id, keys: try words.map(key)), environment: environment)
  }

  private static func key(_ word: String) throws -> ControlKey {
    guard let key = ControlKey(parsing: word) else {
      throw UsageError(
        "no key \(word); a key is a letter, digit or US punctuation key, or one of "
          + ControlKey.names.joined(separator: ", ") + ", after any of ctrl-, alt-, shift-, cmd-",
        topic: ControlCommand.panes.rawValue,
      )
    }
    return key
  }
}

import MultishellCore

/// What setting keys on a command would do: refused, a question because
/// another command holds them, or allowed, with what a pane loses.
enum ShortcutJudgement: Hashable, Sendable {
  case allowed(ShortcutWarning?)
  case refused(ShortcutRefusal)
  case taken(holder: ShortcutCommand)
}

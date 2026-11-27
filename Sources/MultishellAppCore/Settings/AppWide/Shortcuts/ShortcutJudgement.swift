import MultishellCore

/// What setting keys on a command or an action would do: refused, held by
/// another command, or allowed, with what a pane loses.
enum ShortcutJudgement: Hashable, Sendable {
  case allowed(ShortcutWarning?)
  case refused(ShortcutRefusal)
  case taken(holder: ShortcutCommand)
}

import MultishellCore

// Declared order is the order the scope bar draws and Tab steps through.
// swiftlint:disable sorted_enum_cases
/// What the quick switcher lists, everything or one kind of thing.
public enum QuickSwitcherScope: CaseIterable, Identifiable, Sendable {
  case all
  case agents
  case worktrees
  case tabs
  case files
  case commands

  public var id: Self { self }
}
// swiftlint:enable sorted_enum_cases

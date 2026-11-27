// Declared order is the order the steps run in.
// swiftlint:disable sorted_enum_cases
/// The steps of a create, in order, for a sheet to show while it waits. A
/// hook step is reported only when that hook has a script.
public enum WorktreeCreationStep: Sendable, Equatable {
  case preCreateHook
  case addingWorktree
}
// swiftlint:enable sorted_enum_cases

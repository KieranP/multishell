/// The window a dialog is shown in. Settings is a scene of its own, so a
/// dialog raised there but shown in the workspace window sat behind it.
public enum DialogWindow: Equatable, Sendable {
  case settings
  case workspace
}

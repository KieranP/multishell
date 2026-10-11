/// What choosing a menu item by its titles came to.
public enum PlatformMenuOutcome: Sendable, Equatable {
  case disabled
  case notFound
  case performed
}

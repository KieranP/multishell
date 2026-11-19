/// A step's own checkbox over its unsent items: AppKit's on, mixed and off.
public enum HandoffGroupState: Equatable, Sendable {
  case checked
  case mixed
  case unchecked
}

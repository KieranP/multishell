/// What `multishell panes find` and `tabs find` ask of a find bar.
public enum FindBarAction: Codable, Equatable, Sendable {
  case close
  case next
  /// The bar opens with this text, as typing it into the field.
  case open(String)
  case previous
}

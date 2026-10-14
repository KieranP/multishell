/// What `multishell panes find` asks of a pane's find bar.
public enum PaneFindAction: Codable, Equatable, Sendable {
  case close
  case next
  /// The bar opens on the pane with this text, as typing it into the field.
  case open(String)
  case previous
}

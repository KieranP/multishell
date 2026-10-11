/// What `multishell panes find` asks of a pane's find bar.
public enum PaneFindAction: Codable, Equatable, Sendable {
  case close
  case next
  case previous
  /// The bar opens on the pane with this text, as typing it into the field.
  case search(String)
}

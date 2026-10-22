/// A colour an entry of a theme's `ui` section may set, written in the file as
/// its raw value. Which keys an entry takes is `InterfaceSection.colorKeys`.
public enum InterfaceColorKey: String, Sendable {
  case accent
  case added
  case background
  case blockBackground = "block_background"
  case border
  case changed
  case divider
  case done
  case failed
  case fieldBackground = "field_background"
  case fieldBorder = "field_border"
  case fieldText = "field_text"
  case fieldTextSecondary = "field_text_secondary"
  case fill
  case highlight
  case hitch
  case knob
  case merged
  case removed
  case selection
  case selectionBackground = "selection_background"
  case seriesApp = "series_app"
  case seriesChildren = "series_children"
  case seriesTerminals = "series_terminals"
  case stall
  case text
  case textSecondary = "text_secondary"
  case textTertiary = "text_tertiary"
  case waiting
  case working
}

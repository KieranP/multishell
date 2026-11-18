import MultishellCore

/// A chip's fill on an area's fill: the fill again where translucent, a shade up,
/// else the selection, as an opaque fill drawn twice reads as none.
public enum ChipOnFill {
  public static func colorKey(in section: InterfaceSection, of theme: Theme) -> InterfaceColorKey {
    theme.interfaceRGB(.fill, in: section).opacity < 1 ? .fill : .selectionBackground
  }
}

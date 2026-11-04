/// Which tabs in a strip take a wash under the pointer: those behind the shown
/// one, which keeps its content's fill. See Docs/design/tabs-and-groups.md.
public enum TabHoverWash {
  public static func isWashed(onShownTab isShown: Bool, isHovered: Bool) -> Bool {
    isHovered && !isShown
  }
}

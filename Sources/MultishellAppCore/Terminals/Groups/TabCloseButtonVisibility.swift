/// Which tabs in a strip draw their X: every group's shown tab, and any tab
/// under the pointer. See Docs/design/tabs-and-groups.md.
public enum TabCloseButtonVisibility {
  public static func isVisible(onShownTab isShown: Bool, isHovered: Bool) -> Bool {
    isShown || isHovered
  }
}

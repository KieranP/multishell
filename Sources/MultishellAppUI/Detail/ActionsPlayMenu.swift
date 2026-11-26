import MultishellAppCore
import MultishellCore
import SwiftUI

/// The header's play button: the project's actions with their state and keys,
/// a dot on it while one runs. It reads the run states, so only it redraws.
struct ActionsPlayMenu: View {
  let model: AppModel
  let worktree: Worktree
  let theme: Theme

  @Environment(\.accessibilityReduceMotion) private var reducesMotion
  @State private var isHovered = false
  @State private var presenter = ActionsPlayMenuPresenter()

  var body: some View {
    if let menu = model.actionMenu(for: worktree) {
      PlainGlyphButton(help: t("actions.play-help"), action: showMenu) {
        HeaderGlyph(symbol: "play.fill")
          .glyphHover(isHovered, palette: theme.header, resting: theme.header.textSecondary)
          .overlay { runningBadge(menu) }
          .background(theme.header.background)
      }
      .background(ViewAnchor { presenter.anchor = $0 })
      .tracksHover($isHovered)
    }
  }

  /// Badged on the glyph's own corner as a tab's state is, the clear square
  /// standing in for the glyph inside the button's larger frame.
  private func runningBadge(_ menu: ActionMenu) -> some View {
    Color.clear
      .frame(width: UIMetrics.headerGlyphSize, height: UIMetrics.headerGlyphSize)
      .cornerBadge(
        onGlyphOf: UIMetrics.headerGlyphSize,
        badgeScale: theme.stateDotScale,
        ringFill: theme.header.background,
        ringWash: nil,
        menu.isAnyRunning
          ? StateDot(
            state: .running,
            theme: theme,
            palette: theme.header,
            diameter: UIMetrics.cornerBadgeSize(onGlyphOf: UIMetrics.headerGlyphSize),
          ) : nil,
      )
  }

  private func showMenu() {
    guard let menu = model.actionMenu(for: worktree) else { return }
    // The open menu hides the pointer's exit, which would leave the glyph lit.
    isHovered = false
    let worktree = worktree
    presenter.show(
      menu,
      now: Date(),
      theme: theme,
      reducingMotion: reducesMotion,
      runAction: { [model] name in model.runAction(named: name, in: worktree) },
      editActions: { [model] in model.editActions(of: worktree) },
    )
  }
}

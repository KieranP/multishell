import AppKit
import MultishellAppCore
import MultishellCore
import MultishellHighlight
import SwiftUI

/// A file tab's text in SwiftUI; its layout goes when the tab is hidden, the
/// model keeping its scroll and find. Rebuilt on a font change.
struct DiffDocumentRepresentable: NSViewRepresentable {
  /// What the view last drew, so an update redraws only what changed.
  @MainActor
  final class Coordinator {
    var theme: Theme?
    var findMatchesShown: FindMatchesShown?
    var hasPaintedFind = false
    var highlighting: Task<Void, Never>?
  }

  let model: AppModel
  let tabID: FileTab.ID
  /// The file's path, which picks the language it is highlighted in.
  let path: String
  let text: DiffDisplayText
  let theme: Theme
  let font: FileFont
  let find: FindMatchesShown

  /// A hidden tab drops its view; its parse's spans would land on nothing.
  static func dismantleNSView(_ view: DiffDocumentView, coordinator: Coordinator) {
    coordinator.highlighting?.cancel()
  }

  func makeNSView(context: Context) -> DiffDocumentView {
    let view = DiffDocumentView(
      geometry: DiffRowGeometry(fontFamily: font.family, fontSize: font.size)
    )
    view.textView.onFocus = { [weak model] in model?.noteFileTabFocused(tabID) }
    view.textView.onSelectionChange = { [weak model] text in
      model?.noteFileTabSelection(text, of: tabID)
    }
    view.onScrolledTo = { [weak model] scroll in model?.noteFileTabScrolled(tabID, to: scroll) }
    if let scroll = model.fileTabScroll(of: tabID) { view.restore(scroll) }
    // What the dropped view drew, so only a search or step since moves the selection.
    if let shown = model.fileFindShown(of: tabID) {
      context.coordinator.findMatchesShown = FindMatchesShown(shown)
    }
    return view
  }

  func updateNSView(_ view: DiffDocumentView, context: Context) {
    let coordinator = context.coordinator
    let textChanged = view.textView.displayText != text || coordinator.theme != theme
    if textChanged {
      coordinator.theme = theme
      view.show(text, theme: theme)
      coordinator.highlighting?.cancel()
      coordinator.highlighting = Task { @MainActor [weak view, weak model] in
        let started = ContinuousClock.now
        let runs = await DiffHighlighting.spans(for: text, path: path)
        let parse = started.duration(to: .now)
        guard !Task.isCancelled,
          let applied = await view?.textView.applyHighlights(runs, for: text, theme: theme)
        else { return }
        model?.noteFileTabHighlighted(tabID, cost: parse + applied)
      }
    }
    if textChanged || coordinator.findMatchesShown != find {
      let previous = coordinator.findMatchesShown
      coordinator.findMatchesShown = find
      view.textView.showFindMatches(
        find,
        after: previous,
        isFirstPaint: !coordinator.hasPaintedFind,
        tint: theme.findMatchTint,
      )
      coordinator.hasPaintedFind = true
      model.noteFileFindShown(find.shown, of: tabID)
    }
    view.textView.takeKeyboard(ifAskedBy: model, for: tabID)
  }

  func makeCoordinator() -> Coordinator { Coordinator() }
}

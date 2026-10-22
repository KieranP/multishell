import AppKit
import MultishellAppCore
import MultishellCore
import SwiftUI

/// A file tab's text in SwiftUI; its layout goes when the tab is hidden, the
/// model keeping its scroll and find. Rebuilt on a font change.
struct DiffDocumentRepresentable: NSViewRepresentable {
  /// What the view last drew, so an update redraws only what changed.
  @MainActor
  final class Coordinator {
    var theme: Theme?
    let paintedFindMatches: PaintedFindMatches
    var highlighting: Task<Void, Never>?

    init(paintedFindMatches: PaintedFindMatches) {
      self.paintedFindMatches = paintedFindMatches
    }
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
        guard
          let cost = await DiffTextView.highlight(
            text,
            path: path,
            theme: theme,
            on: { view?.textView },
          )
        else { return }
        model?.noteFileTabHighlighted(tabID, cost: cost)
      }
    }
    if let shown = coordinator.paintedFindMatches.paint(
      find,
      on: view.textView,
      textChanged: textChanged,
      tint: theme.findMatchTint,
    ) {
      model.noteFileFindShown(shown, of: tabID)
    }
    view.textView.takeKeyboard(ifAskedBy: model, for: tabID)
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(paintedFindMatches: PaintedFindMatches(resuming: model.fileFindShown(of: tabID)))
  }
}

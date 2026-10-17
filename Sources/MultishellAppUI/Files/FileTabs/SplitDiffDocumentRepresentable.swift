import AppKit
import MultishellAppCore
import MultishellCore
import MultishellHighlight
import SwiftUI

/// A file tab's split in SwiftUI, rebuilt on a font change as the unified view
/// is. Find runs on the right side, the file on disk.
struct SplitDiffDocumentRepresentable: NSViewRepresentable {
  /// What the view last drew, so an update redraws only what changed.
  @MainActor
  final class Coordinator {
    var split: SplitDiff?
    var theme: Theme?
    let paintedFindMatches: PaintedFindMatches
    var highlighting: Task<Void, Never>?

    init(paintedFindMatches: PaintedFindMatches) {
      self.paintedFindMatches = paintedFindMatches
    }
  }

  let model: AppModel
  let tabID: FileTab.ID
  let path: String
  let split: SplitDiff
  let theme: Theme
  let font: FileFont
  let find: FindMatchesShown

  /// A hidden tab drops its view; its parse's spans would land on nothing.
  static func dismantleNSView(_ view: SplitDiffDocumentView, coordinator: Coordinator) {
    coordinator.highlighting?.cancel()
  }

  func makeNSView(context: Context) -> SplitDiffDocumentView {
    let view = SplitDiffDocumentView(
      geometry: DiffRowGeometry(fontFamily: font.family, fontSize: font.size)
    )
    for side in [view.committed, view.onDisk] {
      side.textView.onFocus = { [weak model] in model?.noteFileTabFocused(tabID) }
    }
    view.onDisk.textView.onSelectionChange = { [weak model] text in
      model?.noteFileTabSelection(text, of: tabID)
    }
    view.onScrolledTo = { [weak model] scroll in model?.noteFileTabScrolled(tabID, to: scroll) }
    if let scroll = model.fileTabScroll(of: tabID) { view.restore(scroll) }
    return view
  }

  func updateNSView(_ view: SplitDiffDocumentView, context: Context) {
    let coordinator = context.coordinator
    let textChanged = coordinator.split != split || coordinator.theme != theme
    if textChanged {
      coordinator.split = split
      coordinator.theme = theme
      view.show(split, theme: theme)
      coordinator.highlighting?.cancel()
      coordinator.highlighting = Task { @MainActor [weak view, weak model] in
        var cost = Duration.zero
        for (side, text) in [(view?.committed, split.committed), (view?.onDisk, split.onDisk)] {
          let started = ContinuousClock.now
          let runs = await DiffHighlighting.spans(for: text, path: path)
          let parse = started.duration(to: .now)
          guard !Task.isCancelled,
            let applied = await side?.textView.applyHighlights(runs, for: text, theme: theme)
          else { return }
          cost += parse + applied
        }
        model?.noteFileTabHighlighted(tabID, cost: cost)
      }
    }
    if let shown = coordinator.paintedFindMatches.paint(
      find,
      on: view.onDisk.textView,
      textChanged: textChanged,
      tint: theme.findMatchTint,
    ) {
      model.noteFileFindShown(shown, of: tabID)
    }
    view.onDisk.textView.takeKeyboard(ifAskedBy: model, for: tabID)
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(paintedFindMatches: PaintedFindMatches(resuming: model.fileFindShown(of: tabID)))
  }
}

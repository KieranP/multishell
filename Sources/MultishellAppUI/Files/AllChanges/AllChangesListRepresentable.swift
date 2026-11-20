import AppKit
import MultishellAppCore
import MultishellCore
import MultishellHighlight
import SwiftUI

/// The All changes tab's files as a list of views, each coloured as it is built;
/// see Docs/design/files/all-changes-tab.md.
struct AllChangesListRepresentable: NSViewRepresentable {
  typealias Coordinator = AllChangesListCoordinator

  /// Measuring the font's widest character took a tenth of each scroll.
  @MainActor private static var geometryByFont: (font: FileFont, geometry: DiffRowGeometry)?

  let model: AppModel
  let tab: AllChangesTab
  let document: AllChangesDocument
  let theme: Theme
  let font: FileFont
  let find: FindMatchesShown
  /// Comments to send by path, counted once by the tab's body for every header.
  var pendingComments: [String: Int] = [:]

  var geometry: DiffRowGeometry {
    if let cached = Self.geometryByFont, cached.font == font { return cached.geometry }
    var geometry = DiffRowGeometry(fontFamily: font.family, fontSize: font.size)
    geometry.verticalInset = 0
    Self.geometryByFont = (font, geometry)
    return geometry
  }

  static func dismantleNSView(_ list: AllChangesListView, coordinator: Coordinator) {
    for (_, view) in list.builtFiles { view.highlighting?.cancel() }
  }

  func makeCoordinator() -> Coordinator { Coordinator() }

  func makeNSView(context: Context) -> AllChangesListView {
    let coordinator = context.coordinator
    coordinator.representable = self
    let list = AllChangesListView(frame: .zero)
    list.leadingInset = CGFloat(UIMetrics.allChangesBoxMargin)
    list.scrollerMargin = CGFloat(UIMetrics.allChangesScrollerMargin)
    // The representable's at each call: the text size can change with the list kept.
    list.estimate = { [weak coordinator] index in
      guard let coordinator, let representable = coordinator.representable else { return 0 }
      return coordinator.estimate(
        index,
        geometry: representable.geometry,
        metrics: representable.model.metrics,
      )
    }
    list.makeFile = { [weak list, weak coordinator] isSplit in
      coordinator?.representable?.makeFile(isSplit: isSplit, in: list)
    }
    list.configure = { [weak coordinator] view, index in
      guard let coordinator else { return }
      coordinator.representable?.configure(view, at: index, coordinator: coordinator)
    }
    let tabID = tab.id
    list.onNearFiles = { [weak model, weak coordinator] near in
      guard let document = coordinator?.document else { return }
      let indices = near.clamped(to: document.sections.indices)
      model?.noteAllChangesFilesNear(Set(indices.map { document.sections[$0].path }), in: tabID)
    }
    list.onScroll = { [weak list, weak coordinator] in
      guard let list, let coordinator else { return }
      coordinator.representable?.noteScroll(of: list, coordinator: coordinator)
    }
    // A restore or a first show reports no scroll; the top file is noted anyway.
    list.onLaidOut = { [weak list, weak coordinator] in
      guard let list, let coordinator, let representable = coordinator.representable else { return }
      representable.restoreScroll(of: list, coordinator: coordinator)
      representable.noteScroll(of: list, coordinator: coordinator)
    }
    list.changesRotor = AllChangesChangesRotor(list: list, coordinator: coordinator)
    coordinator.savedScroll = model.allChangesScroll(of: tab.id)
    return list
  }

  func updateNSView(_ list: AllChangesListView, context: Context) {
    let coordinator = context.coordinator
    coordinator.representable = self
    coordinator.pendingComments = pendingComments
    let textChanged = coordinator.document != document || coordinator.theme != theme
    if textChanged {
      // A switch changes each file's height, so the line at the top is put back, not its offset.
      if coordinator.document.map({ $0.isSplit != document.isSplit }) == true,
        coordinator.pendingReveal == nil
      {
        coordinator.savedScroll = model.allChangesScroll(of: tab.id)
      }
      coordinator.noteDocument(document)
      coordinator.theme = theme
      list.show(
        document.sections.indices.map { index in
          AllChangesFileKey(
            path: document.sections[index].path,
            isSplit: document.showsSplitColumns(ofSection: index),
          )
        }
      )
    } else {
      for (index, view) in list.builtFiles { configure(view, at: index, coordinator: coordinator) }
    }
    if let shown = coordinator.paint(
      find,
      on: list,
      tint: theme.findMatchTint,
      geometry: geometry,
      textChanged: textChanged,
    ) {
      model.noteFileFindShown(shown, of: tab.id)
    }
    for direction in model.takeChangeStepRequests(tab.id) {
      coordinator.step(direction, on: list, geometry: geometry)
    }
    noteChangeSteps(of: list, coordinator: coordinator)
    if let card = model.takeReviewCardReveal(tab.id) {
      revealReviewCard(card, on: list, coordinator: coordinator)
    }
    if let path = model.takeAllChangesFileReveal(tab.id) {
      coordinator.savedScroll = nil
      coordinator.pendingReveal = path
    }
    list.takeKeyboard(ifAskedBy: model, for: tab.id)
    list.needsLayout = true
  }

  private func makeFile(isSplit: Bool, in list: AllChangesListView?) -> AllChangesFileView {
    let view = AllChangesFileView(
      geometry: geometry,
      isSplit: isSplit,
      scrollsWith: list?.scrollView,
    )
    let tabID = tab.id
    let columns = [view.split?.committed, view.mainColumn].compactMap(\.self)
    for column in columns {
      column.textView.onFocus = { [weak model] in model?.noteFileTabFocused(tabID) }
      // Kept by the view as it is reused: the representable, and its document, stay out.
      column.onCommentOnRows = { [weak model, weak view] start, end, side in
        guard let model, let section = view?.slice?.section else { return }
        model.openReviewComposer(
          fromRow: start,
          toRow: end,
          ofSection: section,
          side: side,
          in: tabID,
        )
      }
    }
    for column in columns {
      column.textView.forwardsScrollsTo = list
    }
    // Several files' texts share the tab's selection: the focused one's is the user's.
    view.mainColumn.textView.onSelectionChange = { [weak model, weak view] text in
      guard view?.mainColumn.textView.isFirstResponder == true else { return }
      model?.noteFileTabSelection(text, of: tabID)
    }
    return view
  }

  private func configure(
    _ view: AllChangesFileView,
    at index: Int,
    coordinator: Coordinator,
  ) {
    guard let slice = coordinator.slice(index) else { return }
    let section = document.sections[index]
    let showsTextAnew = view.show(
      slice,
      header: AllChangesFileHeader(
        model: model,
        tabID: tab.id,
        worktreeID: tab.worktreeID,
        section: section,
        pendingComments: coordinator.pendingComments[section.path] ?? 0,
        theme: theme,
      ),
      item: { [model, tab, theme, path = section.path] item, codeX in
        AnyView(
          AllChangesGapItemView(
            model: model,
            tab: tab,
            path: path,
            item: item,
            codeX: codeX,
            theme: theme,
          )
        )
      },
      itemHeight: { [metrics = model.metrics] item in
        CGFloat(metrics.allChangesHeight(of: item.kind))
      },
      theme: theme,
    )
    showReviewCards(on: view, at: index)
    if showsTextAnew { coordinator.highlight(view, theme: theme) }
    coordinator.dress(view, at: index)
  }

  /// Which ways the bar's arrows can step from the boxed change or the top.
  func noteChangeSteps(of list: AllChangesListView, coordinator: Coordinator) {
    let geometry = geometry
    let origin = coordinator.stepOrigin(on: list, geometry: geometry)
    model.noteChangeSteps(
      coordinator.outermostSteps(on: list, geometry: geometry).changeSteps(from: origin),
      of: tab.id,
    )
  }
}

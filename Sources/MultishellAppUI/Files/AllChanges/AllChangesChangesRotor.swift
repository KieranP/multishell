import AppKit
import MultishellAppCore
import MultishellCore

/// The All changes list's one Changes rotor: every file's changed lines in list
/// order, the list scrolled to each so its file's view is built to read it.
@MainActor
final class AllChangesChangesRotor: NSObject,
  @MainActor NSAccessibilityCustomRotorItemSearchDelegate
{
  private weak var list: AllChangesListView?
  private weak var coordinator: AllChangesListCoordinator?
  /// The last item given and its stop: its text view may since show another file.
  private var given: (item: NSAccessibilityCustomRotor.ItemResult, stop: AllChangesFileRow)?

  init(list: AllChangesListView, coordinator: AllChangesListCoordinator) {
    self.list = list
    self.coordinator = coordinator
  }

  func rotor(
    _ rotor: NSAccessibilityCustomRotor,
    resultFor parameters: NSAccessibilityCustomRotor.SearchParameters,
  ) -> NSAccessibilityCustomRotor.ItemResult? {
    guard let list, let coordinator, let document = coordinator.document,
      let geometry = coordinator.representable?.geometry
    else { return nil }
    let direction: CycleDirection = parameters.searchDirection == .next ? .next : .previous
    let current = parameters.currentItem.flatMap { item in
      given.flatMap { $0.item === item ? $0.stop : nil } ?? stop(of: item, in: list)
    }
    guard let stop = document.changedRow(direction, from: current, slice: coordinator.slice)
    else { return nil }
    coordinator.scroll(to: stop, below: list.clipHeight / 3, on: list, geometry: geometry)
    let item = textView(showing: stop, in: list)?.changesRotorItem(atRow: stop.row)
    given = item.map { ($0, stop) }
    return item
  }

  /// Split's left where the change is a removed line beside the right's padding.
  private func textView(
    showing stop: AllChangesFileRow,
    in list: AllChangesListView,
  )
    -> DiffTextView?
  {
    guard let view = list.file(at: stop.section) else { return nil }
    if let committed = view.split?.committed,
      view.slice?.changeIsCommittedSideOnly(atRow: stop.row) == true
    {
      return committed.textView
    }
    return view.mainColumn.textView
  }

  /// The file and row an item stands on, where its file is still built: one the
  /// rotor did not give, VoiceOver's own place.
  private func stop(
    of item: NSAccessibilityCustomRotor.ItemResult,
    in list: AllChangesListView,
  ) -> AllChangesFileRow? {
    let target = item.targetElement
    for (index, view) in list.builtFiles {
      for column in [view.mainColumn, view.split?.committed].compactMap(\.self)
      where column.textView === target {
        let row = column.textView.displayText.row(atOffset: item.targetRange.location)
        return AllChangesFileRow(section: index, row: row)
      }
    }
    return nil
  }
}

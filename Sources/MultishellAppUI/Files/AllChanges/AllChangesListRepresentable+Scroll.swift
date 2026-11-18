import AppKit
import MultishellAppCore
import MultishellCore

/// The All changes list's place: the file at the top noted as it scrolls, and
/// a saved scroll or a Changes click put back once the list has a size.
extension AllChangesListRepresentable {
  /// The file at the top, lit in Changes and its header held over the rows,
  /// and the scroll by that file's line.
  func noteScroll(of list: AllChangesListView, coordinator: Coordinator) {
    guard let document = coordinator.document, let index = list.fileIndex(at: list.scrollY),
      let top = list.top(ofFile: index)
    else { return }
    let y = list.scrollY
    // A clicked file too near the end to reach the top stays lit until the list moves.
    if coordinator.scrollYLeftByReveal.map({ abs($0 - y) > 0.5 }) ?? true {
      coordinator.scrollYLeftByReveal = nil
      model.noteAllChangesTopFile(
        AllChangesTopFile(
          path: document.sections[index].path,
          headerBarTop: Double(top),
          nextHeaderBarTop: list.top(ofFile: index + 1).map(Double.init),
          scrolledTo: Double(y),
          barHeight: UIMetrics.allChangesHeaderBarHeight,
        ),
        in: tab.id,
      )
    }
    noteChangeSteps(of: list, coordinator: coordinator)
    guard coordinator.savedScroll == nil, coordinator.pendingReveal == nil else { return }
    let rows = document.sections[index].rows
    guard !rows.isEmpty else {
      model.noteAllChangesScrolled(tab.id, to: document.scroll(atTopOf: index, x: 0))
      return
    }
    let intoRows = y - top - AllChangesFileView.headerHeight
    let row =
      list.file(at: index).map { $0.mainColumn.textView.geometry.topRow(atScrollOffset: intoRows) }
      ?? Double(max(0, intoRows) / geometry.rowHeight)
    let documentRow = Double(rows.lowerBound) + min(max(0, row), Double(rows.count - 1))
    if let scroll = document.scroll(atRow: documentRow, x: 0) {
      model.noteAllChangesScrolled(tab.id, to: scroll)
    }
  }

  /// A Changes click's file at the top, else the saved scroll's line, once the
  /// list has a size.
  func restoreScroll(of list: AllChangesListView, coordinator: Coordinator) {
    guard list.clipHeight > 0, let document = coordinator.document else { return }
    if let path = coordinator.pendingReveal {
      coordinator.pendingReveal = nil
      if let index = document.section(at: path), let top = list.top(ofFile: index) {
        coordinator.scrollYLeftByReveal = list.scrollY(reaching: top)
        list.scroll(toY: top)
      }
      return
    }
    guard let scroll = coordinator.savedScroll, let index = document.section(at: scroll.path),
      let top = list.top(ofFile: index)
    else {
      coordinator.savedScroll = nil
      return
    }
    // A file still to be read has no rows to put back: its top, until it is
    // read or the list is scrolled off it.
    guard !coordinator.isUnread(index) else {
      if let held = coordinator.offsetIntoUnreadSavedFile, abs(list.scrollY - top - held) > 0.5 {
        coordinator.savedScroll = nil
        coordinator.offsetIntoUnreadSavedFile = nil
        return
      }
      list.scroll(toY: top)
      coordinator.offsetIntoUnreadSavedFile = list.scrollY - top
      return
    }
    coordinator.savedScroll = nil
    coordinator.offsetIntoUnreadSavedFile = nil
    guard !document.sections[index].rows.isEmpty, let row = document.row(of: scroll) else {
      list.scroll(toY: top)
      return
    }
    let fileRow = row - Double(document.sections[index].rows.lowerBound)
    let cut = CGFloat(fileRow - fileRow.rounded(.down)) * geometry.rowHeight
    coordinator.scroll(
      to: AllChangesSteps.Stop(section: index, row: Int(fileRow)),
      below: -cut,
      on: list,
      geometry: geometry,
    )
  }
}

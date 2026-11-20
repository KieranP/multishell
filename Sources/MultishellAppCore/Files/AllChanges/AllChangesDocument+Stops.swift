/// Where the bar's arrows stop across the files; see "The bar's step buttons go
/// across files" in Docs/design/files/all-changes-tab.md.
extension AllChangesDocument {
  /// The files still to be read, by section: each shows a Reading notice.
  public var unreadSections: Set<Int> {
    Set(gapItems.filter { $0.kind == .notice(.reading) }.map(\.section))
  }

  /// Each change, and each file still to be read as one stop at its top: a
  /// step onto it brings it near, so it is read and its changes follow.
  public var changeStops: [AllChangesFileRow] {
    var rowsBySection: [Int: [Int]] = [:]
    for start in text.changeStarts {
      guard let section = section(atRow: start) else { continue }
      rowsBySection[section, default: []].append(start - sections[section].rows.lowerBound)
    }
    let unread = unreadSections
    return sections.indices.flatMap { index -> [AllChangesFileRow] in
      let rows = unread.contains(index) ? [0] : rowsBySection[index] ?? []
      return rows.map { AllChangesFileRow(section: index, row: $0) }
    }
  }
}

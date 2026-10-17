/// `tabs` kept in the order the groups draw, which every open, move and repair
/// ends with; see Docs/design/tabs-and-groups.md.
extension Workspace {
  /// Orders each group's tabs in `tabs` as the group does, keeping its places,
  /// for an older build reading order there; one missing a tab is left alone.
  mutating func alignTabsToGroupOrder() {
    let byID = tabs.keyedByID()
    var ordered: [TabGroup.ID: IndexingIterator<[TerminalTab]>] = [:]
    for group in tabGroups {
      let inOrder = group.tabOrder.compactMap { byID[$0] }.filter { $0.groupID == group.id }
      guard Set(inOrder.map(\.id)).count == tabs.count(where: { $0.groupID == group.id }),
        inOrder.count == Set(inOrder.map(\.id)).count
      else { continue }
      ordered[group.id] = inOrder.makeIterator()
    }
    var aligned = tabs
    for index in aligned.indices {
      if let tab = ordered[aligned[index].groupID]?.next() { aligned[index] = tab }
    }
    if aligned != tabs { tabs = aligned }
  }
}

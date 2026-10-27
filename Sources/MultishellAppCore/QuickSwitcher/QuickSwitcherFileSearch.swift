/// The last file search's rows and the text it ran for, kept with the tree it
/// searched so a render that moved neither does not search every path again.
struct QuickSwitcherFileSearch {
  let query: QuickSwitcherQuery
  let items: [QuickSwitcherItem]
}

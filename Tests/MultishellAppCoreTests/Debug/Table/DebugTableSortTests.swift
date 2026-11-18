import Testing

@testable import MultishellAppCore

@Suite
struct DebugTableSortTests {
  private enum Column: DebugSortableColumn {
    case name
    case size

    static let defaultSort = DebugTableSort(column: Self.size, isAscending: false)

    var sortsAscendingFirst: Bool { self == .name }
    var sortTitle: String { self == .name ? "name" : "size" }
  }

  private struct Row: DebugSortableRow {
    let sortName: String
    let size: Double?

    func sortKey(by column: Column) -> DebugSortKey? {
      switch column {
      case .name: .text(sortName)
      case .size: size.map(DebugSortKey.number)
      }
    }
  }

  @Test func aSecondClickOnTheSortedColumnTurnsItRound() {
    let flipped = Column.defaultSort.selecting(.size)
    #expect(flipped == DebugTableSort(column: Column.size, isAscending: true))
    #expect(flipped.selecting(.size) == Column.defaultSort)
  }

  @Test func anotherColumnStartsAtItsOwnFirstDirection() {
    #expect(Column.defaultSort.selecting(.name).isAscending)
    #expect(!DebugTableSort(column: Column.name, isAscending: true).selecting(.size).isAscending)
  }

  @Test func aRowWithNoReadingGoesLastWhicheverWayTheColumnRuns() {
    let rows = [
      Row(sortName: "a", size: nil), Row(sortName: "b", size: 1), Row(sortName: "c", size: 2),
    ]
    for isAscending in [true, false] {
      let order = DebugTableSort(column: Column.size, isAscending: isAscending).ordered(rows)
      #expect(order.last?.sortName == "a")
    }
  }

  @Test func tiesGoByNameSoARedrawKeepsTheOrder() {
    let rows = [Row(sortName: "b", size: 1), Row(sortName: "a", size: 1)]
    for isAscending in [true, false] {
      let order = DebugTableSort(column: Column.size, isAscending: isAscending).ordered(rows)
      #expect(order.map(\.sortName) == ["a", "b"])
    }
  }

  @Test func textSortsAToZWhateverItsCase() {
    let rows = [Row(sortName: "Zed", size: nil), Row(sortName: "acme", size: nil)]
    let order = DebugTableSort(column: Column.name, isAscending: true).ordered(rows)
    #expect(order.map(\.sortName) == ["acme", "Zed"])
  }

  @Test func theCaptionNamesTheSortedColumn() {
    #expect(Column.defaultSort.title == "size")
  }
}

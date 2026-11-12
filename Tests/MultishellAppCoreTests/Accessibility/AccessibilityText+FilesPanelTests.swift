import Testing

@testable import MultishellAppCore

@Suite
struct AccessibilityTextFilesPanelTests {
  private static let row = FileTreeRow(
    path: "Sources/App.swift",
    name: "App.swift",
    parentFolder: nil,
    depth: 1,
    isFolder: false,
    isExpanded: false,
    holdsChange: false,
    changeKind: nil,
    lineCounts: nil,
    isRepository: false,
    isIgnored: false,
    isOpenable: true,
  )

  @Test func aFileRowSaysHowManyCommentsWaitToBeSent() {
    #expect(
      AccessibilityText.fileRow(Self.row, pendingReviewComments: 2).hasSuffix("2 comments to send")
    )
    #expect(!AccessibilityText.fileRow(Self.row, pendingReviewComments: 0).contains("to send"))
  }
}

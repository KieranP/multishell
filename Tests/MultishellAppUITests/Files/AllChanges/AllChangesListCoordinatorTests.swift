import AppKit
import MultishellGitKit
import SwiftUI
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI
@testable import MultishellCore

@Suite @MainActor
struct AllChangesListCoordinatorTests {
  private static func swiftFile(_ path: String) -> AllChangesFile {
    AllChangesFile(
      change: AllChangesFileChange(path: path, kind: .modified, lineCounts: nil),
      content: .read(
        FileTabReading(
          content: .text(
            FileTabRows(
              lines: [
                DiffLine(kind: .removed, oldNumber: 1, newNumber: nil, text: "let a = 1"),
                DiffLine(kind: .added, oldNumber: nil, newNumber: 1, text: "let a = 2"),
              ],
              marksStaging: true,
            )
          ),
          isFileGone: false,
        )
      ),
      signature: nil,
    )
  }

  private static func document(_ files: [AllChangesFile]) -> AllChangesDocument {
    AllChangesDocument(
      AllChangesReading(listed: files.map(\.change), files: files),
      collapsed: [],
      heldOpen: [:],
    )
  }

  @Test func aParseLandingAfterAFileAboveWentColoursItsFileFromTheDocumentItWasCutFrom() async {
    let coordinator = AllChangesListCoordinator()
    let before = Self.document([Self.swiftFile("a.swift"), Self.swiftFile("b.swift")])
    coordinator.noteDocument(before)
    let view = AllChangesFileView(
      geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12),
      isSplit: false,
      scrollsWith: nil,
    )
    _ = view.show(
      before.slice(ofSection: 1),
      header: .sample(of: before, section: 1),
      item: { _, _ in AnyView(EmptyView()) },
      itemHeight: { _ in 0 },
      theme: Theme.builtins[0],
    )

    coordinator.highlight(view, theme: Theme.builtins[0])
    coordinator.noteDocument(Self.document([Self.swiftFile("b.swift")]))
    await view.highlighting?.value

    #expect(view.mainColumn.textView.appliedRuns?.isEmpty == false)
  }
}

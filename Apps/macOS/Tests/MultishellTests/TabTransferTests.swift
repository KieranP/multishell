import Foundation
import Testing
import UniformTypeIdentifiers

@testable import Multishell

/// A tab is dragged by `onDrag`, which hands over an item provider, and
/// dropped on a worktree row by `dropDestination`, which reads the same tab
/// back through `Transferable`. The two ends never meet in a test that can
/// stage a drag, so what is checked here is the contract between them: the
/// bytes the provider carries, under the type identifier the representation
/// reads them from. A mismatch is a drop that silently decodes nothing.
@Suite
struct TabTransferTests {
  @Test func theProviderCarriesTheJSONTheRepresentationReadsBack() async throws {
    let id = UUID()
    let provider = TabTransfer(id: id).itemProvider()

    #expect(provider.registeredTypeIdentifiers == [TabTransfer.contentType.identifier])

    let data: Data = try await withCheckedThrowingContinuation { continuation in
      provider.loadDataRepresentation(forTypeIdentifier: TabTransfer.contentType.identifier) {
        data, error in
        switch (data, error) {
        case (let data?, _): continuation.resume(returning: data)
        case (nil, let error?): continuation.resume(throwing: error)
        case (nil, nil): continuation.resume(throwing: CocoaError(.coderInvalidValue))
        }
      }
    }

    #expect(try JSONDecoder().decode(TabTransfer.self, from: data).id == id)
  }

  /// Its own type, not the plain text a project is dragged as: the sidebar
  /// asks a drag whether it conforms to `.text` before offering a project
  /// its reorder, and a tab that answered yes would be swallowed by it.
  ///
  /// Asked of the provider, not of `UTType.conforms(to:)`. That answers
  /// from the type declarations LaunchServices has registered, so a machine
  /// that has run a built bundle knows this type and one that has not says
  /// it conforms to nothing at all. What routes a drag is the identifier on
  /// the item, which is the same either way.
  @Test func aTabIsNotDraggedAsText() {
    let provider = TabTransfer(id: UUID()).itemProvider()

    #expect(provider.hasItemConformingToTypeIdentifier(TabTransfer.contentType.identifier))
    #expect(!provider.hasItemConformingToTypeIdentifier(UTType.text.identifier))
  }
}

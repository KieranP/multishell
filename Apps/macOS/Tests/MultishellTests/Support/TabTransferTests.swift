import Foundation
import Testing
import UniformTypeIdentifiers

@testable import Multishell

/// No test can stage a drag, so these check the contract between `onDrag` and
/// `dropDestination`; a mismatch is a drop that silently decodes nothing.
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

  /// The sidebar offers a project reorder to any `.text` drag. Asked of the provider, since
  /// `UTType.conforms(to:)` answers from whatever LaunchServices has registered on this Mac.
  @Test func aTabIsNotDraggedAsText() {
    let provider = TabTransfer(id: UUID()).itemProvider()

    #expect(provider.hasItemConformingToTypeIdentifier(TabTransfer.contentType.identifier))
    #expect(!provider.hasItemConformingToTypeIdentifier(UTType.text.identifier))
  }
}

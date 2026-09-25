import Foundation
import Testing
import UniformTypeIdentifiers

@testable import MultishellAppUI

@Suite
struct TabTransferTests {
  /// The sidebar offers a project reorder to any `.text` drag. Asked of the provider, since
  /// `UTType.conforms(to:)` answers from whatever LaunchServices has registered on this Mac.
  @Test func aTabIsNotDraggedAsText() {
    let provider = TabTransfer.itemProvider()

    #expect(provider.registeredTypeIdentifiers == [TabTransfer.contentType.identifier])
    #expect(!provider.hasItemConformingToTypeIdentifier(UTType.text.identifier))
  }
}

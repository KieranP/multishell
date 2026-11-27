import Testing
import UniformTypeIdentifiers

@testable import MultishellAppUI

@Suite
struct ActionRowTransferTests {
  /// A text field takes any `.text` drop as typing, which pasted the row's id
  /// into the name or command field it was dropped on.
  @Test func aRowIsNotDraggedAsText() {
    let provider = ActionRowTransfer.itemProvider()

    #expect(provider.registeredTypeIdentifiers == [ActionRowTransfer.contentType.identifier])
    #expect(!provider.hasItemConformingToTypeIdentifier(UTType.text.identifier))
  }
}

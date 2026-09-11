import CoreTransferable
import Foundation
import MultishellCore
import UniformTypeIdentifiers

/// A tab on the drag pasteboard, with a type of its own: one type for this
/// and a project would offer every target to both drags.
struct TabTransfer: Codable, Transferable {
  let id: TerminalTab.ID

  /// Declared as an exported type in the bundle's `Info.plist`; see
  /// `Scripts/make-app.sh`.
  static let contentType = UTType(exportedAs: "io.multishell.tab")

  static var transferRepresentation: some TransferRepresentation {
    CodableRepresentation(contentType: contentType)
  }

  /// What the drag hands over. `.onDrag` rather than `.draggable`, which
  /// would not say which tab is moving as the drag starts.
  func itemProvider() -> NSItemProvider {
    let provider = NSItemProvider()
    provider.registerDataRepresentation(
      forTypeIdentifier: Self.contentType.identifier, visibility: .ownProcess
    ) { completion in
      do {
        completion(try JSONEncoder().encode(self), nil)
      } catch {
        completion(nil, error)
      }
      return nil
    }
    return provider
  }
}

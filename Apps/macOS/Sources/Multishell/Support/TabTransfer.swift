import CoreTransferable
import Foundation
import MultishellCore
import UniformTypeIdentifiers

/// A tab on the drag pasteboard.
///
/// Its own type rather than the plain text a project is dragged as: one type
/// for both would offer every target to both drags, and a worktree row would
/// light up for a project it cannot take and swallow the drop meant to
/// reorder the sidebar.
struct TabTransfer: Codable, Transferable {
  let id: TerminalTab.ID

  /// Declared as an exported type in the bundle's `Info.plist`; see
  /// `Scripts/make-app.sh`.
  static let contentType = UTType(exportedAs: "io.multishell.tab")

  static var transferRepresentation: some TransferRepresentation {
    CodableRepresentation(contentType: contentType)
  }

  /// What the drag hands over. `.draggable` would build this, but the strip
  /// draws its insertion line from the tab that is moving, and only
  /// `.onDrag` says which tab that is as the drag starts. The bytes are the
  /// same JSON `transferRepresentation` reads, so the sidebar's drop still
  /// decodes it. Own-process only: the drag never leaves the app.
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

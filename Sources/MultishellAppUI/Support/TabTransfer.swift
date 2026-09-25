import Foundation
import UniformTypeIdentifiers

/// A tab on the drag pasteboard, with a type of its own: one type for this
/// and a project would offer every target to both drags. Only the type is
/// read; every drop takes the tab from `AppModel.tabDrag`.
enum TabTransfer {
  /// Declared as an exported type in the bundle's `Info.plist`; see
  /// `Scripts/make-app.sh`.
  static let contentType = UTType(exportedAs: "io.multishell.tab")

  /// What the drag hands over. `.onDrag` rather than `.draggable`, which
  /// would not say which tab is moving as the drag starts.
  static func itemProvider() -> NSItemProvider {
    let provider = NSItemProvider()
    provider.registerDataRepresentation(
      forTypeIdentifier: contentType.identifier, visibility: .ownProcess
    ) { completion in
      completion(Data(), nil)
      return nil
    }
    return provider
  }
}

import Foundation
import UniformTypeIdentifiers

/// A tab on the drag pasteboard, typed apart from a project's so neither drag is
/// offered the other's targets. Every drop takes the tab from `AppModel.tabDrag`.
enum TabTransfer {
  /// Declared as an exported type in the bundle's `Info.plist`; see
  /// `Resources/Info.plist.in`.
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

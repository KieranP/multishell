import Foundation
import UniformTypeIdentifiers

/// An Actions page row on the drag pasteboard. Not text, which a name or
/// command field took as typing. The page holds which row is moving.
enum ActionRowTransfer {
  /// Declared as an exported type in the bundle's `Info.plist`; see
  /// `Resources/Info.plist.in`.
  static let contentType = UTType(exportedAs: "io.multishell.action-row")

  static func itemProvider() -> NSItemProvider {
    .inApp(contentType)
  }
}

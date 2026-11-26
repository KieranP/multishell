import Foundation
import UniformTypeIdentifiers

extension NSItemProvider {
  /// A drag that carries only its type, seen by this process alone: what moves
  /// is held by whoever started it.
  static func inApp(_ type: UTType) -> NSItemProvider {
    let provider = NSItemProvider()
    provider.registerDataRepresentation(
      forTypeIdentifier: type.identifier,
      visibility: .ownProcess,
    ) { completion in
      completion(Data(), nil)
      return nil
    }
    return provider
  }
}

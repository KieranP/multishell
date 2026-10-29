/// A stand-in's JSON this build cannot read, with where it stopped and why.
public struct ServiceStandInUnreadable: Error, Equatable {
  public let reason: String

  init(_ error: any Error) {
    guard let decoding = error as? DecodingError else {
      reason = String(describing: error)
      return
    }
    let context: DecodingError.Context
    var missingKey: (any CodingKey)?
    switch decoding {
    case .keyNotFound(let key, let found):
      // The decoder's path stops at the object the key is missing from.
      context = found
      missingKey = key

    case .dataCorrupted(let found), .typeMismatch(_, let found), .valueNotFound(_, let found):
      context = found

    @unknown default:
      reason = String(describing: error)
      return
    }
    let path = (context.codingPath + [missingKey].compactMap(\.self)).map { key in
      key.intValue.map(String.init) ?? key.stringValue
    }
    let description = missingKey.map { "\($0.stringValue) is missing" } ?? context.debugDescription
    reason = (path.isEmpty ? "" : "at " + path.joined(separator: ".") + ": ") + description
  }

  /// `path` as the decoder spells one, `ciRuns.1.id`.
  init(at path: String, _ description: String) {
    reason = "at \(path): \(description)"
  }
}

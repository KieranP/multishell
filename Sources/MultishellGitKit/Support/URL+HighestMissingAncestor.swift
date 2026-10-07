import Foundation
import MultishellCore

extension URL {
  var highestMissingAncestor: URL? {
    let (existing, unmade) = splitAtDeepestExisting()
    return unmade.first.map { existing.appendingPathComponent($0) }
  }
}

import Foundation

extension URL {
  public var modificationDate: Date? {
    try? resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
  }
}

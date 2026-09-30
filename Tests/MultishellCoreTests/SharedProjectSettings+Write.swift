import Foundation

@testable import MultishellCore

extension SharedProjectSettings {
  @discardableResult func write(to repository: URL) throws -> SharedProjectSettings {
    let contents = try fileContents()
    try contents.data.write(to: Self.file(in: repository), options: .atomic)
    return contents.settings
  }
}

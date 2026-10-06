import Foundation

/// Swift strings as C strings, many alive at once for a C call, which nested
/// `withCString` closures cannot give for a list of any length.
enum CStrings {
  static func with<Result>(
    _ strings: [String], _ body: ([UnsafePointer<CChar>]) -> Result
  ) -> Result {
    let copies = strings.map { strdup($0)! }
    defer { for copy in copies { free(copy) } }
    return body(copies.map { UnsafePointer($0) })
  }
}

import Foundation

/// The process is out of file descriptors: each live shell and each child's
/// pipes hold some, under the limit DescriptorLimit raises at launch.
public struct DescriptorUnavailable: Error, CustomStringConvertible {
  public let code: Int32

  /// The log's form. What the user is shown is `PresentedError`'s.
  public var description: String {
    "could not open a file descriptor: \(String(cString: strerror(code))) (\(code))"
  }
}

import CryptoKit
import Foundation

/// The sha256 of a file's bytes, as the trust answers store it.
enum FileDigest {
  /// The digest of `data`, sixty-four lowercase hex characters.
  static func sha256(of data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }
}

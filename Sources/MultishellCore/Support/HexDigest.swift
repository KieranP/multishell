import CryptoKit
import Foundation

/// A digest as lowercase hex: what the trust answers store and review files are named by.
enum HexDigest {
  /// The digest of `data`, sixty-four lowercase hex characters.
  static func sha256(of data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }
}

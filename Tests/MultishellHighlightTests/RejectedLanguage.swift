import SwiftTreeSitter

/// A grammar from an ABI newer than tree-sitter reads, so `setLanguage` refuses it, as
/// after a grammar bump. Only `abi_version`, a `TSLanguage`'s first field, is read.
enum RejectedLanguage {
  static let language: Language = {
    let fields = UnsafeMutablePointer<UInt32>.allocate(capacity: 64)
    fields.initialize(repeating: 0, count: 64)
    fields.pointee = UInt32(Language.version + 1)
    return Language(OpaquePointer(fields))
  }()
}

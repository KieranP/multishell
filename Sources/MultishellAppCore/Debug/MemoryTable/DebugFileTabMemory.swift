/// The open file tabs' text, estimated and labelled in Debug Info rather than
/// left in the app's row; see Docs/design/files.md.
struct DebugFileTabMemory: Equatable, Sendable {
  static let noTabs = Self(tabCount: 0, textMemory: 0)

  let tabCount: Int
  let textMemory: UInt64
}

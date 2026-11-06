/// The open file tabs' text and images, estimated and labelled in Debug Info rather than
/// left in the app's row; see Docs/design/files/file-tabs.md.
struct DebugFileTabMemory: Equatable, Sendable {
  static let noTabs = Self(tabCount: 0, contentMemory: 0)

  let tabCount: Int
  let contentMemory: UInt64
}

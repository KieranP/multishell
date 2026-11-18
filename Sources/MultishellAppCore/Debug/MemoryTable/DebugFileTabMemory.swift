/// The open file tabs' text and images, estimated and shown as a line under the
/// app's heap in use; see Docs/design/files/file-tabs.md.
struct DebugFileTabMemory: Equatable, Sendable {
  static let noTabs = Self(tabCount: 0, contentMemory: 0)

  let tabCount: Int
  let contentMemory: UInt64
}

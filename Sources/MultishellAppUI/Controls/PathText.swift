import SwiftUI

/// A path on one line, cut from the front so the end that tells it apart stays.
struct PathText: View {
  let path: String

  init(_ path: String) {
    self.path = path
  }

  var body: some View {
    Text(path)
      .font(.system(size: 11, design: .monospaced))
      .foregroundStyle(.secondary)
      .lineLimit(1)
      .truncationMode(.head)
  }
}

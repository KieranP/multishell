import SwiftUI

/// A path on one line, cut from the front so the end that tells it apart stays.
struct PathText: View {
  let path: String

  var body: some View {
    Text(path)
      .font(.system(size: UIMetrics.unscaledMonospacedSize, design: .monospaced))
      .foregroundStyle(.secondary)
      .lineLimit(1)
      .truncationMode(.head)
  }

  init(_ path: String) {
    self.path = path
  }
}

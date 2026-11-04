import MultishellAppCore
import SwiftUI

/// A worktree's name that gives up its prefix before its leaf: whole, then
/// `…/leaf`, then the leaf cut in its middle. See Docs/design/worktrees.md.
struct BranchNameText: View {
  let name: String
  let font: Font
  let color: Color
  let prefixColor: Color

  var body: some View {
    let parts = BranchNameParts(name)
    ViewThatFits(in: .horizontal) {
      if !parts.prefix.isEmpty {
        line(prefix: parts.prefix, leaf: parts.leaf).fixedSize()
        line(prefix: .elidedPathStart, leaf: parts.leaf).fixedSize()
      }
      Text(parts.leaf)
        .foregroundStyle(color)
        .lineLimit(1)
        .truncationMode(.middle)
    }
    .font(font)
    .help(name)
    .accessibilityLabel(name)
  }

  private func line(prefix: String, leaf: String) -> some View {
    HStack(spacing: 0) {
      Text(prefix).foregroundStyle(prefixColor)
      Text(leaf).foregroundStyle(color)
    }
    .lineLimit(1)
  }
}

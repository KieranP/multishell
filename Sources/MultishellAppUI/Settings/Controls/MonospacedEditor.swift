import SwiftUI

/// One multi-line monospaced field: a hook's script, or a file list. The only
/// placeholder is what the repository ships, so grey means that alone.
struct MonospacedEditor: View {
  let label: String
  let info: String
  let placeholder: String?
  @Binding var text: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      InfoLabel(label, info: info)
      MonospacedTextEditor(
        text: $text,
        fontSize: UIMetrics.unscaledMonospacedSize,
        fill: HierarchicalShapeStyle.quaternary.opacity(0.5),
        border: nil,
        minHeight: 48,
        maxHeight: 96,
      )
      .overlay(alignment: .topLeading) {
        if text.isEmpty, let placeholder {
          Text(placeholder)
            .font(.system(size: UIMetrics.unscaledMonospacedSize, design: .monospaced))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .allowsHitTesting(false)
        }
      }
    }
    .padding(.vertical, 2)
  }
}

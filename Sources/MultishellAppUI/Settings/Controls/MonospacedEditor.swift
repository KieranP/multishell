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
        placeholder: placeholder,
        fontSize: UIMetrics.unscaledMonospacedSize,
        fill: HierarchicalShapeStyle.quaternary.opacity(0.5),
        border: nil,
        minHeight: 48,
        maxHeight: 96,
      )
    }
    .padding(.vertical, 2)
  }
}

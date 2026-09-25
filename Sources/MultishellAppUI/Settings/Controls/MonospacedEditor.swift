import SwiftUI

/// One multi-line monospaced field: a hook's script, or a file list. The only
/// placeholder is what the repository ships, so grey means that alone.
struct MonospacedEditor: View {
  let title: String
  let info: String
  let placeholder: String?
  @Binding var text: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      InfoLabel(title, info: info)
      TextEditor(text: $text)
        .font(.system(size: 11, design: .monospaced))
        .scrollContentBackground(.hidden)
        .frame(minHeight: 48, maxHeight: 96)
        .padding(4)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 5))
        .overlay(alignment: .topLeading) {
          if text.isEmpty, let placeholder {
            Text(placeholder)
              .font(.system(size: 11, design: .monospaced))
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

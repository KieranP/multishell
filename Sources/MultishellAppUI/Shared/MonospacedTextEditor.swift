import SwiftUI

/// A multi-line monospaced field on a rounded fill: a setting's script or file
/// list, and the merge form's commit message.
struct MonospacedTextEditor<Fill: ShapeStyle>: View {
  private static var inset: Double { 4 }
  private static var cornerRadius: Double { 5 }

  @Binding var text: String
  let fontSize: Double
  let fill: Fill
  /// `nil` draws none.
  let border: Color?
  let minHeight: Double
  let maxHeight: Double

  var body: some View {
    TextEditor(text: $text)
      .font(.system(size: fontSize, design: .monospaced))
      .scrollContentBackground(.hidden)
      .frame(minHeight: minHeight, maxHeight: maxHeight)
      .padding(Self.inset)
      .background(fill, in: RoundedRectangle(cornerRadius: Self.cornerRadius))
      .overlay {
        if let border {
          RoundedRectangle(cornerRadius: Self.cornerRadius)
            .strokeBorder(border, lineWidth: UIMetrics.hairlineThickness)
        }
      }
  }
}

import SwiftUI

/// The (i) beside a settings row, holding its help. Hover shows a tooltip and
/// a click the same text as a popover, a tooltip alone being easy to miss.
struct InfoButton: View {
  let text: String

  @State private var showsInfo = false

  init(_ text: String) { self.text = text }

  var body: some View {
    Button {
      showsInfo.toggle()
    } label: {
      Image(systemName: "info.circle")
        .foregroundStyle(.secondary)
        .frame(width: 20, height: 20)
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .help(text)
    .popover(isPresented: $showsInfo, arrowEdge: .bottom) {
      Text(text)
        .font(.system(size: 12))
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: 320, alignment: .leading)
        .padding()
    }
  }
}

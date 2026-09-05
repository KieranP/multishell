import SwiftUI

/// The (i) beside a settings row, holding the help that used to sit under
/// it as a caption. Hover shows it as a tooltip; a click opens the same text
/// as a popover, because a tooltip alone is easy to miss and answers no
/// click.
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

/// A form row with its (i) right after the label, in the form's label
/// column; the control keeps the content column to itself. Wrapping a
/// labelled control in a plain `HStack` would pull its label out of that
/// column.
struct InfoRow<Content: View>: View {
  let label: String
  let info: String
  @ViewBuilder let content: () -> Content

  init(_ label: String, info: String, @ViewBuilder content: @escaping () -> Content) {
    self.label = label
    self.info = info
    self.content = content
  }

  var body: some View {
    LabeledContent {
      HStack(spacing: 8) { content().labelsHidden() }
    } label: {
      InfoLabel(label, info: info)
    }
  }
}

/// Label text with its (i) beside it.
struct InfoLabel: View {
  let text: String
  let info: String

  init(_ text: String, info: String) {
    self.text = text
    self.info = info
  }

  var body: some View {
    HStack(spacing: 4) {
      Text(text)
      InfoButton(info)
    }
  }
}

/// A toggle with its (i) after its title.
struct InfoToggle: View {
  let title: String
  let info: String
  @Binding var isOn: Bool

  init(_ title: String, info: String, isOn: Binding<Bool>) {
    self.title = title
    self.info = info
    _isOn = isOn
  }

  var body: some View {
    Toggle(isOn: $isOn) { InfoLabel(title, info: info) }
  }
}

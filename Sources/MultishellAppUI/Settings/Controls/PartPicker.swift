import SwiftUI

/// The segmented row that picks which part of a split settings page shows;
/// see Docs/design/settings.md.
struct PartPicker<Part: CaseIterable & Hashable>: View where Part.AllCases: RandomAccessCollection {
  let label: String
  @Binding var selection: Part
  let title: (Part) -> String

  var body: some View {
    Section {
      Picker(label, selection: $selection) {
        ForEach(Part.allCases, id: \.self) { Text(title($0)).tag($0) }
      }
      .segmentedAcrossRow()
    }
  }
}

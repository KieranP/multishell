import SwiftUI

extension View {
  func ticking(_ now: Binding<Date>, every interval: Duration) -> some View {
    task {
      while !Task.isCancelled {
        try? await Task.sleep(for: interval)
        guard !Task.isCancelled else { return }
        now.wrappedValue = Date()
      }
    }
  }
}

import SwiftUI

extension View {
  func ticking(_ now: Binding<Date>, every interval: Duration) -> some View {
    task {
      // Shown again after a while away, it starts from the time it is now.
      now.wrappedValue = Date()
      while !Task.isCancelled {
        try? await Task.sleep(for: interval)
        guard !Task.isCancelled else { return }
        now.wrappedValue = Date()
      }
    }
  }
}

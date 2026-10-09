import SwiftUI
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI
@testable import MultishellCore

@Suite @MainActor
struct WorkerListTests {
  private func width(describedAs description: String) -> CGFloat {
    let worker = Worker(id: "a0", type: "general-purpose", description: description)
    let list = WorkerList(
      workers: [worker],
      theme: .multishellDark,
      metrics: UIMetrics(fontSize: 13),
    )
    return NSHostingView(rootView: list).fittingSize.width
  }

  @Test func aLongDescriptionIsCutRatherThanWideningTheList() {
    let short = width(describedAs: "Review")
    let long = width(describedAs: String(repeating: "Review the diff ", count: 13))
    #expect(long <= WorkerList.maximumWidth)
    #expect(short < long)
  }
}

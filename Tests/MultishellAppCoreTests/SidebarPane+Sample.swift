import Foundation
import MultishellCore

@testable import MultishellAppCore

extension SidebarPane {
  static func sample(
    title: String = "claude",
    position: PanePosition? = nil,
    isFocused: Bool = false,
    state: SessionState? = nil,
    since: Date? = nil,
    workers: [Worker] = [],
    agentID: String? = nil,
    agentName: String? = nil,
  ) -> SidebarPane {
    SidebarPane(
      id: UUID(),
      title: title,
      position: position,
      isFocused: isFocused,
      state: state,
      since: since,
      workers: workers,
      agentID: agentID,
      agentName: agentName,
    )
  }
}

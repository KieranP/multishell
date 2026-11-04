import Foundation

@testable import MultishellServices

extension PullRequestCheck {
  static func sample(
    name: String = "build",
    workflow: String? = "CI",
    status: CIRunStatus = .passed,
    isRequired: Bool = true,
    link: URL? = nil,
  ) -> Self {
    PullRequestCheck(
      name: name,
      workflow: workflow,
      status: status,
      isRequired: isRequired,
      link: link,
    )
  }
}

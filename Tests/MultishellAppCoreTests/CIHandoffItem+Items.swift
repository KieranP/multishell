import MultishellServices

@testable import MultishellAppCore

extension CIHandoffItem {
  static func items(of run: CIRun, workflows: [CIWorkflow], report: CIFailureReport?) -> [Self] {
    items(
      of: run,
      workflows: workflows,
      report: report,
      unplaced: report?.unplaced(among: workflows) ?? [],
    )
  }
}

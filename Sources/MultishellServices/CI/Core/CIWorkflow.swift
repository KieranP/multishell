/// One workflow of a CI run and its jobs.
public struct CIWorkflow: Hashable, Sendable {
  public let name: String
  public let status: CIRunStatus
  public let jobs: [CIJob]
}

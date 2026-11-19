/// A job's place on the CI page: its workflow's index in the run, then its own.
public struct CIJobPosition: Hashable, Sendable {
  let workflow: Int
  let job: Int

  public init(workflow: Int, job: Int) {
    self.workflow = workflow
    self.job = job
  }
}

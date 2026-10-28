/// What failed in a run, each excerpt shown under the job it is about.
public struct CIFailureReport: Hashable, Sendable {
  let excerpts: [CIFailureExcerpt]

  /// A job run twice, as parallel executions are, has its excerpts joined.
  public func excerpt(ofJob job: String, inWorkflow workflow: String) -> String? {
    let texts = excerpts.filter { $0.job == job && ($0.workflow ?? workflow) == workflow }
      .map(\.text)
    return texts.isEmpty ? nil : texts.joined(separator: "\n\n")
  }

  /// The excerpts no listed job holds, shown after the workflows.
  public func unplaced(among workflows: [CIWorkflow]) -> [String] {
    excerpts.filter { excerpt in
      !workflows.contains { workflow in
        (excerpt.workflow ?? workflow.name) == workflow.name
          && workflow.jobs.contains { $0.name == excerpt.job }
      }
    }
    .map(\.text)
  }
}

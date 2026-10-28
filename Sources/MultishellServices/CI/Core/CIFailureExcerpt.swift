/// What a failed run's report says of one job, as the provider words it.
struct CIFailureExcerpt: Hashable, Sendable {
  /// `nil` where the report named none.
  let workflow: String?
  /// `nil` where the report named none, so no job's row can hold it.
  let job: String?
  let text: String
}

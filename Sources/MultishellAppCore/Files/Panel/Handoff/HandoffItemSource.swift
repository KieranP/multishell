/// The read that lists a sendable item, which prunes its kind alone: a failed
/// thread read must not keep the checks' old keys, nor drop the threads'.
enum HandoffItemSource: Equatable, Sendable {
  case checks
  case ciRun
  case threads
}

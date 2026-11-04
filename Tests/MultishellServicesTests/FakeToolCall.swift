/// One run of a `FakeTool`: its arguments as `$*` joins them, and the runner's
/// variables as `NAME=value` pairs.
struct FakeToolCall: Equatable {
  let arguments: String
  let variables: String
}

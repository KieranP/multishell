/// What a task on the main actor answered, for a test that cannot await it first.
@MainActor
final class MainActorBox<Value> {
  var value: Value?
}

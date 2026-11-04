/// Who asked: a click beeps where it is refused and takes the keyboard; a
/// request is answered instead, the keyboard staying unless its target is in view.
enum Asker: Sendable {
  case click
  case request
}

/// A `style` or `on…` word the text scan found, an attribute's name only where the tree
/// says so, and which of the two it is.
struct InjectableAttributeCandidate {
  enum Kind {
    case style
    case handler
  }

  let range: Range<Int>
  let kind: Kind
}

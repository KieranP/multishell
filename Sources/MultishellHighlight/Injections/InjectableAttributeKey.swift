/// An element's `style` or `on…` attribute by its lowercased name, so a repeated one is
/// read once.
struct InjectableAttributeKey: Hashable {
  let tagNameStart: Int
  let name: String
}

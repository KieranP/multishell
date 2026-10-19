/// What a host file's injection query finds: injections, and keywords Svelte's
/// grammar leaves in a block head, `then` in `{#await p then v}`.
struct HostInjections {
  var injections: [Injection] = []
  var keywords: [Range<Int>] = []

  mutating func add(_ injection: Injection?) {
    if let injection { injections.append(injection) }
  }

  mutating func add(_ other: Self) {
    injections += other.injections
    keywords += other.keywords
  }
}

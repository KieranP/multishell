/// What one `for-each-ref` listed, and whether it was asked for the
/// upstreams' remote and name, which its retry leaves out.
struct BranchRefList {
  let refs: [BranchRef]
  let namesUpstreams: Bool
}

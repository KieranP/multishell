/// Whether a branch's reflog held the tip of its same-named remote branch, which
/// git does not track for it, asked at both tips. See Docs/design/services.md.
struct PublishedTipCheck: Equatable {
  let branchTip: String?
  let remoteTip: String
  let countsAsPublished: Bool
}

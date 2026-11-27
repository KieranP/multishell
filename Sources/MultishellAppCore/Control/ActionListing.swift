/// `actions list`: a worktree's actions as its play button lists them.
struct ActionListing: Encodable, Equatable {
  struct Action: Encodable, Equatable {
    let name: String
    /// `idle`, `running`, `done` or `failed`.
    let state: String
    /// As `config global` spells keys, `nil` for none.
    let keys: String?
  }

  let worktree: String
  let actions: [Action]
  /// The repository's, listed but not run until its file is trusted.
  let awaitingTrust: [String]
}

/// `gh pr view --json headRefOid`: the commit a pull request heads now.
struct GitHubHeadRecord: Decodable {
  static let fields = ["headRefOid"]

  let headRefOid: String
}

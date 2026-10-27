import Testing

@testable import MultishellServices

@Suite
struct RemoteRepositoryTests {
  @Test(arguments: [
    "git@github.com:KieranP/multishell.git",
    "git@github.com:KieranP/multishell",
    "https://github.com/KieranP/multishell.git",
    "https://github.com/KieranP/multishell",
    "ssh://git@github.com:22/KieranP/multishell.git",
    "git://github.example.com/KieranP/multishell",
  ])
  func everySpellingOfARemoteNamesItsOwnerAndRepository(url: String) throws {
    let repository = try #require(RemoteRepository(remoteURL: url))
    #expect(repository == RemoteRepository(owner: "KieranP", name: "multishell"))
  }

  @Test func aNestedGroupIsTheOwnerWholeAndTheLastComponentTheName() {
    #expect(
      RemoteRepository(remoteURL: "https://gitlab.com/team/sub/app.git")
        == RemoteRepository(owner: "team/sub", name: "app")
    )
  }

  @Test(arguments: [
    "/srv/git/repo.git", "../sibling", "https://host/only", "git@host:repo.git", "",
    "file:///srv/git/team/app.git",
  ])
  func aPathOrAUrlWithoutAnOwnerNamesNoRepository(url: String) {
    #expect(RemoteRepository(remoteURL: url) == nil)
  }

  @Test func ownersAndNamesCompareWithoutCaseAsHostsDo() {
    let remote = RemoteRepository(owner: "kieranp", name: "MultiShell")
    #expect(remote.isSame(as: RemoteRepository(owner: "KieranP", name: "multishell")))
    #expect(!remote.isSame(as: RemoteRepository(owner: "someone", name: "multishell")))
  }
}

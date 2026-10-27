import Testing

@testable import MultishellGitKit

@Suite
struct GitRemoteParserTests {
  @Test func eachRemoteIsListedOnceWithTheUrlItFetchesFrom() {
    let remotes = GitRemoteParser.parse(
      """
      origin\tgit@github.com:KieranP/multishell.git (fetch)
      origin\tgit@github.com:KieranP/multishell.git (push)
      my.fork\thttps://example.com/me/multishell (fetch)
      my.fork\tssh://example.com/me/push-only (push)
      """
    )

    #expect(
      remotes == [
        GitRemote(name: "origin", url: "git@github.com:KieranP/multishell.git"),
        GitRemote(
          name: "my.fork",
          url: "https://example.com/me/multishell",
          pushURL: "ssh://example.com/me/push-only",
        ),
      ]
    )
  }

  @Test func aLineOfAnyOtherShapeIsDroppedAndTheRestSurvive() {
    let remotes = GitRemoteParser.parse(
      "nonsense\n\tno-name (fetch)\nnourl\t (fetch)\norigin\t/srv/repo.git (fetch)\n"
    )
    #expect(remotes == [GitRemote(name: "origin", url: "/srv/repo.git")])
  }

  /// What git 2.56 prints for a remote a partial clone filters.
  @Test func aRemoteWithAPartialCloneFilterIsKept() {
    let remotes = GitRemoteParser.parse(
      "origin\tgit@github.com:o/r.git (fetch) [blob:none]\norigin\tgit@github.com:o/r.git (push)\n"
    )
    #expect(remotes == [GitRemote(name: "origin", url: "git@github.com:o/r.git")])
  }

  @Test func aRemotePushingElsewhereKeepsItsPushURL() {
    let remotes = GitRemoteParser.parse(
      "origin\tgit@github.com:team/r.git (fetch)\norigin\tgit@github.com:me/r.git (push)\n"
    )
    #expect(remotes.first?.pushURL == "git@github.com:me/r.git")
  }
}

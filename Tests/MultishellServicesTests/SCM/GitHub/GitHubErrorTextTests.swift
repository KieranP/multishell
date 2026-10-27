import Testing

@testable import MultishellServices

@Suite
struct GitHubErrorTextTests {
  @Test func aRepositoryWithNoGitHubRemoteIsNotHostedThere() {
    let stderr =
      "none of the git remotes configured for this repository point to a known GitHub host. To tell gh about a new GitHub host, please use `gh auth login`"
    #expect(
      GitHubErrorText.failure(from: stderr) == .notHosted,
      "not logged out, though it names the login",
    )
  }

  @Test func aMissingLoginIsLoggedOut() {
    let stderr =
      "To get started with GitHub CLI, please run:  gh auth login\nAlternatively, populate the GH_TOKEN environment variable"
    #expect(GitHubErrorText.failure(from: stderr) == .loggedOut)
  }

  @Test func anyOtherFailureIsPassedOnByItsFirstLine() {
    let stderr = "\nHTTP 502: Bad Gateway (https://api.github.com/graphql)\nretry later"
    #expect(
      GitHubErrorText.failure(from: stderr)
        == .failed("HTTP 502: Bad Gateway (https://api.github.com/graphql)")
    )
  }
}

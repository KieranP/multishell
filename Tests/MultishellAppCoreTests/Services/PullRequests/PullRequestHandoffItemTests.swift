import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellServices

@Suite
struct PullRequestHandoffItemTests {
  @Test func onlyFailingChecksAreItemsAndAnOptionalOneStartsUnchecked() {
    let checks: [PullRequestCheck] = [
      .sample(name: "lint", status: .passed),
      .sample(name: "test", status: .failed, link: URL(string: "https://ci/test")),
      .sample(name: "danger", workflow: nil, status: .failed, isRequired: false),
    ]

    let items = PullRequestHandoffItem.items(checks: checks, headCommit: "tip", threads: [])

    #expect(
      items.map(\.candidate.id) == [
        .check(name: "CI / test", link: URL(string: "https://ci/test"), headCommit: "tip"),
        .check(name: "danger", link: nil, headCommit: "tip"),
      ]
    )
    #expect(items.map(\.candidate.startsChecked) == [true, false])
  }

  @Test func aNewCommentOnAThreadMakesItANewItem() {
    let before = PullRequestHandoffItem.thread(.sample(comments: ["Guard it."])).candidate
    let after = PullRequestHandoffItem.thread(.sample(comments: ["Guard it.", "Still?"])).candidate

    #expect(before.id != after.id)
  }

  @Test func twoFailingChecksSharingALinkAreTwoItems() {
    let link = URL(string: "https://app.netlify.com/deploys/1")
    let checks: [PullRequestCheck] = [
      .sample(name: "deploy-preview", workflow: nil, status: .failed, link: link),
      .sample(name: "header-rules", workflow: nil, status: .failed, link: link),
    ]

    let items = PullRequestHandoffItem.items(checks: checks, headCommit: "tip", threads: [])

    #expect(Set(items.map(\.candidate.id)).count == 2)
  }

  @Test func aCheckWhoseLinkSurvivesAPushIsANewItemAtTheNewHead() {
    let check = PullRequestCheck.sample(
      name: "codecov/patch",
      workflow: nil,
      status: .failed,
      link: URL(string: "https://codecov.io/gh/me/demo"),
    )

    let before = PullRequestHandoffItem.check(check, headCommit: "aaa").candidate
    let after = PullRequestHandoffItem.check(check, headCommit: "bbb").candidate

    #expect(before.id != after.id)
  }
}

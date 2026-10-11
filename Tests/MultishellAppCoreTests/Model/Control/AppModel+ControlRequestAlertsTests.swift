import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelControlRequestAlertsTests {
  @Test func anAlertRaisedUnderARequestThatHasAnsweredIsFiledUnderNone() {
    let harness = Harness()
    let answered = UUID()

    ControlRequestScope.$id.withValue(answered) {
      harness.model.presentedError = PresentedError(title: "Late", message: "From a task")
    }

    #expect(harness.model.alertRecordsOfRequests.isEmpty)
  }

  @Test func twoRequestsAlertsAnswerEachInTheOrderTheyFinishAndTheUsersComesBack() {
    let harness = Harness()
    let model = harness.model
    let users = PresentedError(title: "Users", message: "Up first")
    model.presentedError = users
    let first = UUID()
    let second = UUID()
    model.requestsBeingAnswered.formUnion([first, second])

    ControlRequestScope.$id.withValue(first) {
      model.presentedError = PresentedError(title: "First", message: "Raised first")
    }
    ControlRequestScope.$id.withValue(second) {
      model.presentedError = PresentedError(title: "Second", message: "Raised over it")
    }

    #expect(
      model.finishAnswering(first, with: .done)
        == .refused(.alert(title: "First", message: "Raised first"))
    )
    #expect(
      model.finishAnswering(second, with: .done)
        == .refused(.alert(title: "Second", message: "Raised over it"))
    )
    #expect(model.presentedError?.id == users.id)
    #expect(model.alertRecordsOfRequests.isEmpty)
  }

  @Test func twoRequestsAlertsFinishedInReverseOrderAnswerEachAndTheUsersComesBack() {
    let harness = Harness()
    let model = harness.model
    let users = PresentedError(title: "Users", message: "Up first")
    model.presentedError = users
    let first = UUID()
    let second = UUID()
    model.requestsBeingAnswered.formUnion([first, second])

    ControlRequestScope.$id.withValue(first) {
      model.presentedError = PresentedError(title: "First", message: "Raised first")
    }
    ControlRequestScope.$id.withValue(second) {
      model.presentedError = PresentedError(title: "Second", message: "Raised over it")
    }

    #expect(
      model.finishAnswering(second, with: .done)
        == .refused(.alert(title: "Second", message: "Raised over it"))
    )
    #expect(model.presentedError?.title == "First")
    #expect(
      model.finishAnswering(first, with: .done)
        == .refused(.alert(title: "First", message: "Raised first"))
    )
    #expect(model.presentedError?.id == users.id)
  }

  @Test func aRequestWhoseAlertAClickReplacedAnswersWithItAndLeavesTheClicksUp() {
    let harness = Harness()
    let model = harness.model
    let request = UUID()
    model.requestsBeingAnswered.insert(request)

    ControlRequestScope.$id.withValue(request) {
      model.presentedError = PresentedError(title: "Request", message: "Raised first")
    }
    let users = PresentedError(title: "Users", message: "Raised by a click")
    model.presentedError = users

    #expect(
      model.finishAnswering(request, with: .done)
        == .refused(.alert(title: "Request", message: "Raised first"))
    )
    #expect(model.presentedError?.id == users.id)
  }

  @Test func aRequestWhoseAlertTheUserDismissedStillAnswersWithIt() {
    let harness = Harness()
    let model = harness.model
    let request = UUID()
    model.requestsBeingAnswered.insert(request)

    let alert = ControlRequestScope.$id.withValue(request) {
      let alert = PresentedError(title: "Request", message: "Dismissed")
      model.presentedError = alert
      return alert
    }
    model.answerPresentedError(alert, retrying: false)

    #expect(
      model.finishAnswering(request, with: .done)
        == .refused(.alert(title: "Request", message: "Dismissed"))
    )
    #expect(model.presentedError == nil)
  }

  @Test func aUsersAlertRaisedBetweenTwoOfARequestsAlertsComesBackWhenItFinishes() {
    let harness = Harness()
    let model = harness.model
    let request = UUID()
    model.requestsBeingAnswered.insert(request)

    let first = ControlRequestScope.$id.withValue(request) {
      let alert = PresentedError(title: "First", message: "Over nothing")
      model.presentedError = alert
      return alert
    }
    model.answerPresentedError(first, retrying: false)
    let users = PresentedError(title: "Users", message: "Raised by a click")
    model.presentedError = users
    ControlRequestScope.$id.withValue(request) {
      model.presentedError = PresentedError(title: "Second", message: "Over the user's")
    }

    #expect(
      model.finishAnswering(request, with: .done)
        == .refused(.alert(title: "Second", message: "Over the user's"))
    )
    #expect(model.presentedError?.id == users.id)
  }

  @Test func anAnsweredRequestsLateAlertBetweenTwoOfAnotherRequestsComesBackWhenItFinishes() {
    let harness = Harness()
    let model = harness.model
    let answered = UUID()
    let request = UUID()
    model.requestsBeingAnswered.insert(request)

    let first = ControlRequestScope.$id.withValue(request) {
      let alert = PresentedError(title: "First", message: "Over nothing")
      model.presentedError = alert
      return alert
    }
    model.answerPresentedError(first, retrying: false)
    let late = ControlRequestScope.$id.withValue(answered) {
      let alert = PresentedError(title: "Late", message: "From an answered request's task")
      model.presentedError = alert
      return alert
    }
    ControlRequestScope.$id.withValue(request) {
      model.presentedError = PresentedError(title: "Second", message: "Over the late one")
    }

    _ = model.finishAnswering(request, with: .done)
    #expect(model.presentedError?.id == late.id)
  }

  @Test func aUsersAlertARequestsFirstCoveredComesBackThoughTheUserDismissedTheRequests() {
    let harness = Harness()
    let model = harness.model
    let users = PresentedError(title: "Users", message: "Up first")
    model.presentedError = users
    let request = UUID()
    model.requestsBeingAnswered.insert(request)

    let first = ControlRequestScope.$id.withValue(request) {
      let alert = PresentedError(title: "First", message: "Over the user's")
      model.presentedError = alert
      return alert
    }
    model.answerPresentedError(first, retrying: false)
    ControlRequestScope.$id.withValue(request) {
      model.presentedError = PresentedError(title: "Second", message: "Over nothing")
    }

    _ = model.finishAnswering(request, with: .done)
    #expect(model.presentedError?.id == users.id)
  }

  @Test func anAlertAlreadyStandingStaysWhenARequestRaisesItsOwn() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let standing = PresentedError(title: "Earlier", message: "Still up")
    harness.model.presentedError = standing
    let plain = harness.root.appendingPathComponent("plain", isDirectory: true)
    try FileManager.default.createDirectory(at: plain, withIntermediateDirectories: true)

    _ = await harness.model.answer(.addProject(path: plain.path))

    #expect(harness.model.presentedError?.id == standing.id)
  }

  @Test func anAlertTheModelTookDownWhileARequestRanStaysDown() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (model, request, release) = try await addFolderHeldAtGitCheck(harness) { model in
      model.presentedError = PresentedError(title: "Git missing", message: "Found since")
    }

    model.presentedError = nil
    try release()
    _ = await request.value

    #expect(model.presentedError == nil)
  }

  @Test func anAlertAClickRaisedWhileARequestRanIsTheOneLeftStanding() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (model, request, release) = try await addFolderHeldAtGitCheck(harness) { model in
      model.presentedError = PresentedError(title: "Earlier", message: "Dismissed since")
    }

    model.answerPresentedError(try #require(model.presentedError), retrying: false)
    let clicked = PresentedError(title: "Clicked", message: "Raised meanwhile")
    model.presentedError = clicked
    try release()
    _ = await request.value

    #expect(model.presentedError?.id == clicked.id)
  }

  /// `release` lets the held repository check answer no, so the request
  /// raises its not-a-repository alert over whatever stands by then.
  private func addFolderHeldAtGitCheck(
    _ harness: GitHarness,
    before: (AppModel<FakeSurface>) -> Void,
  ) async throws -> (
    model: AppModel<FakeSurface>,
    request: Task<ControlReply, Never>,
    release: () throws -> Void
  ) {
    let plain = harness.root.appendingPathComponent("plain", isDirectory: true)
    try FileManager.default.createDirectory(at: plain, withIntermediateDirectories: true)
    let gate = harness.root.appendingPathComponent("gate")
    let asked = harness.root.appendingPathComponent("asked")
    let model = try harness.modelWithRepositoryCheckHeld(in: plain, until: gate, asked: asked)
    before(model)
    let request = Task { await model.answer(.addProject(path: plain.path)) }
    try await waitUntil({ FileManager.default.fileExists(atPath: asked.path) }, seconds: 10)
    return (model, request, { try Data().write(to: gate) })
  }
}

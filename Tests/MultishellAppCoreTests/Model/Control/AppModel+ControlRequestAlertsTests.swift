import Foundation
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
}

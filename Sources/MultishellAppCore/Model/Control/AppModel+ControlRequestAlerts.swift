import Foundation
import MultishellCore

extension AppModel {
  private static func refusal(showing alert: PresentedError) -> ControlReply {
    .refused(.alert(title: alert.title, message: alert.message))
  }

  /// The request's newest alert is its answer, up or not; a later request's
  /// alert over one of its takes down to what this one's went up over.
  func finishAnswering(_ requestID: UUID, with reply: ControlReply) -> ControlReply {
    requestsBeingAnswered.remove(requestID)
    guard let alerts = alertsByRequest.removeValue(forKey: requestID) else { return reply }
    for (laterID, later) in alertsByRequest
    where later.covered?.raisingRequestID == requestID {
      alertsByRequest[laterID]?.covered = alerts.covered
    }
    if presentedError?.raisingRequestID == requestID { presentedError = alerts.covered }
    return Self.refusal(showing: alerts.newest)
  }

  /// What stood when the request's first alert went up, or a newer one no request
  /// being answered owns that a later one of its alerts covered; see agents.md.
  func noteAlertRaised(over covered: PresentedError?) {
    guard let alert = presentedError, let id = alert.raisingRequestID,
      id == ControlRequestScope.id, requestsBeingAnswered.contains(id)
    else { return }
    guard alertsByRequest[id] != nil else {
      alertsByRequest[id] = RequestAlerts(newest: alert, covered: covered)
      return
    }
    alertsByRequest[id]?.newest = alert
    guard let covered, !(covered.raisingRequestID.map(requestsBeingAnswered.contains) ?? false)
    else { return }
    alertsByRequest[id]?.covered = covered
  }
}

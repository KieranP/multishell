import Foundation
import MultishellCore

extension AppModel {
  /// A note written to the drops directory and a mention of it pasted into the
  /// agent's prompt, with no Return; no file is left where either fails.
  func deliverHandoff(
    _ document: String,
    named fileName: String,
    sentence: (String) -> String,
    to recipient: HandoffRecipient,
    takingFocus: Bool,
  ) -> HandoffDelivery {
    let file: URL
    do {
      file = try AgentHandoff.write(document, named: fileName, in: dropsDirectory)
    } catch {
      present(error)
      return .notWritten
    }
    guard
      let mention = handoffMention(
        of: file,
        prefixed: fileMentionPrefix(ofAgent: recipient.agentID),
        sentence: sentence,
      ),
      host.paste(mention + " ", into: recipient.id)
    else {
      DropCopies.remove(file.deletingLastPathComponent())
      return .notPasted
    }
    if takingFocus {
      store.focusSession(recipient.id)
      reconcileSessions(takingFocus: true)
    }
    return .delivered
  }

  /// A delivery that did not land as the Send's outcome, said over `page`'s foot;
  /// `nil` for one that did.
  func outcomeNotingMiss(
    of delivery: HandoffDelivery,
    to recipient: HandoffRecipient,
    on page: ServicePage,
    in worktreeID: Worktree.ID,
  ) -> HandoffSendOutcome? {
    switch delivery {
    case .delivered:
      return nil

    case .notPasted:
      noteHandoffMiss(t("handoff.not-pasted", recipient.agentName), on: page, in: worktreeID)
      return .notPasted(to: recipient.id)

    case .notWritten:
      // Its error is presented already; a note under the alert would say it twice.
      return .notWritten
    }
  }

  /// A mention where the agent reads them, else `sentence` around the path, which
  /// alone says nothing. Absolute: the drops directory is outside every worktree.
  private func handoffMention(
    of file: URL,
    prefixed prefix: String?,
    sentence: (String) -> String,
  ) -> String? {
    guard let text = FilePathText.pastedText(for: [file], relativeTo: nil, mentionPrefix: prefix)
    else { return nil }
    return prefix == nil ? sentence(text) : text
  }
}

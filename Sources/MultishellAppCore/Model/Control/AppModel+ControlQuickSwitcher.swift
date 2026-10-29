import MultishellCore

extension AppModel {
  private var quickSwitcherListing: QuickSwitcherListing {
    let results = quickSwitcherResults
    return QuickSwitcherListing(
      scope: quickSwitcher?.scope.commandName ?? QuickSwitcherScope.all.commandName,
      text: quickSwitcher?.text ?? "",
      sections: results.sections.map { section in
        QuickSwitcherListing.Section(
          kind: section.kind.commandName,
          worktreeName: section.kind.worktreeName,
          state: section.kind.state,
          rows: section.items.map { item in
            QuickSwitcherListing.Row(
              kind: item.kind.commandName,
              title: item.title,
              location: item.location,
              state: item.labelledState,
              shortcut: item.shortcut,
              isSelected: item.target == results.selection,
            )
          },
        )
      },
      emptyReason: results.emptyReason?.commandName,
    )
  }

  /// Cmd+P where it is shut, then the scope bar, the field, an arrow and Return,
  /// in that order; the answer is what it lists, or nothing once a row is chosen.
  func replyToQuickSwitcher(_ order: QuickSwitcherOrder) async -> ControlReply {
    // Drawn over the main window alone; with it shut nothing would show it.
    guard platform.isWorkspaceWindowVisible else { return .refused(.noWindow) }
    var scope: QuickSwitcherScope?
    if let word = order.scope {
      guard let named = QuickSwitcherScope(commandName: word) else {
        return .refused(.invalidValue(key: "--scope", value: word))
      }
      scope = named
    }
    if quickSwitcher == nil {
      openQuickSwitcher(scope ?? .all)
    } else if let scope {
      setQuickSwitcherScope(scope)
    }
    if let text = order.text { setQuickSwitcherText(text) }
    await quickSwitcherFilesRead()
    guard quickSwitcher != nil else { return .refused(.quickSwitcherClosed) }
    if let step = order.step { moveQuickSwitcherSelection(step) }
    guard order.choosesSelected else { return .json(quickSwitcherListing) }
    guard let target = quickSwitcherResults.selection else { return .refused(.noSwitcherRow) }
    return await reply(to: chooseQuickSwitcherRow(target, as: .request))
  }

  /// What a click would beep at, or do nothing over, is the request's refusal.
  private func reply(to choice: QuickSwitcherChoice) async -> ControlReply {
    switch choice {
    case .done: return .done
    case .notUp: return .refused(.quickSwitcherClosed)
    case .rowGone: return .refused(.switcherRowGone)

    case .projectWithNoWorktree(let id):
      return .refused(.projectWithNoWorktree(id: ControlID.project(id)))

    case .worktreeNotReady(let id): return .refused(.worktreeNotReady(id: ControlID.worktree(id)))
    case .menuItem(let path, let performing): return reply(to: await performing.value, of: path)
    case .menuItemRefused(let path, let outcome): return reply(to: outcome, of: path)

    case .openingFile(let path, let worktreeID, let opening):
      guard await opening.value == nil else { return .done }
      let isGone = workspace.worktree(worktreeID) == nil
      return .refused(isGone ? .switcherRowGone : .fileNotOpenable(path: path))
    }
  }
}

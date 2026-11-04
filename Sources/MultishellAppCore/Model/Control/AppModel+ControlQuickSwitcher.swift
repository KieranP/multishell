import MultishellCore

extension AppModel {
  private static func listing(
    of results: QuickSwitcherResults,
    in state: QuickSwitcherState,
  ) -> QuickSwitcherListing {
    QuickSwitcherListing(
      scope: state.scope.commandName,
      text: state.text,
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
    let scope = order.scope.flatMap(QuickSwitcherScope.init(commandName:))
    if let word = order.scope, scope == nil {
      let scopes = QuickSwitcherScope.allCases.map(\.commandName)
      return .refused(.noSwitcherScope(name: word, scopes: scopes))
    }
    // Drawn over the main window alone; with it shut nothing would show it.
    guard isWorkspaceWindowOpen else { return .refused(.noWindow) }
    if quickSwitcher == nil {
      openQuickSwitcher(scope ?? .all)
    } else if let scope {
      setQuickSwitcherScope(scope)
    }
    if let text = order.text { setQuickSwitcherText(text) }
    await waitForQuickSwitcherFiles()
    if let step = order.step { moveQuickSwitcherSelection(step) }
    guard let state = quickSwitcher else { return .refused(.quickSwitcherClosed) }
    let results = quickSwitcherResults
    guard order.choosesSelected else { return .json(Self.listing(of: results, in: state)) }
    guard let target = results.selection else { return .refused(.noSwitcherRow) }
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

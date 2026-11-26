import AppKit
import MultishellAppCore
import MultishellCore

/// The play button's menu, built in AppKit rather than SwiftUI so a running
/// action's dot can turn: a menu row shows an image, swapped here frame by frame.
@MainActor
final class ActionsPlayMenuPresenter: NSObject, NSMenuDelegate {
  /// Below the button, where SwiftUI's menu sat.
  private static let gapBelowAnchor: Double = 4

  weak var anchor: NSView?

  private var runAction: (String) -> Void = { _ in }
  private var editActions: () -> Void = {}
  private var theme: Theme?
  private var workingRows: [NSMenuItem] = []
  private var turnsWorkingDots = false
  private var workingFrame = 0
  private var frameTimer: Timer?

  func show(
    _ actionMenu: ActionMenu,
    now: Date,
    theme: Theme,
    reducingMotion: Bool,
    runAction: @escaping (String) -> Void,
    editActions: @escaping () -> Void,
  ) {
    guard let anchor else { return }
    self.theme = theme
    self.runAction = runAction
    self.editActions = editActions
    turnsWorkingDots = actionMenu.turnsWorkingDots(reducingMotion: reducingMotion)
    let menu = NSMenu()
    menu.autoenablesItems = false
    menu.delegate = self
    workingRows = []
    for (index, group) in actionMenu.groups.enumerated() {
      if index > 0 { menu.addItem(.separator()) }
      for item in group {
        menu.addItem(row(for: item, isMarked: actionMenu.marksRows, now: now, theme: theme))
      }
    }
    addAwaitingTrust(actionMenu.awaitingTrust, to: menu)
    if actionMenu.separatesEditItems {
      menu.addItem(.separator())
    }
    if actionMenu.offersReviewAndTrust {
      menu.addItem(editActionsItem(titled: t("actions.review-and-trust")))
    }
    menu.addItem(editActionsItem(titled: t("actions.edit")))
    let below = anchor.isFlipped ? anchor.bounds.height + Self.gapBelowAnchor : -Self.gapBelowAnchor
    menu.popUp(positioning: nil, at: NSPoint(x: 0, y: below), in: anchor)
  }

  func menuWillOpen(_ menu: NSMenu) {
    guard turnsWorkingDots else { return }
    let timer = Timer(
      timeInterval: StateDotImage.workingFrameInterval,
      target: self,
      selector: #selector(showNextWorkingFrame),
      userInfo: nil,
      repeats: true,
    )
    // The common modes include a menu's tracking, in which the default mode waits.
    RunLoop.main.add(timer, forMode: .common)
    frameTimer = timer
  }

  func menuDidClose(_ menu: NSMenu) {
    frameTimer?.invalidate()
    frameTimer = nil
    workingRows = []
  }

  private func row(
    for item: ActionMenuItem,
    isMarked: Bool,
    now: Date,
    theme: Theme,
  ) -> NSMenuItem {
    let row = NSMenuItem(title: item.name, action: #selector(pickAction(_:)), keyEquivalent: "")
    row.target = self
    row.representedObject = item.name
    row.subtitle = item.stateWords(now: now)
    row.setKeys(item.keys, isChanged: true)
    if isMarked {
      row.image = StateDotImage.image(for: item.markedState, theme: theme, frame: workingFrame)
    }
    if item.markedState == .running { workingRows.append(row) }
    return row
  }

  private func addAwaitingTrust(_ names: [String], to menu: NSMenu) {
    guard !names.isEmpty else { return }
    menu.addItem(.sectionHeader(title: t("actions.untrusted-title")))
    for name in names {
      let item = NSMenuItem(title: name, action: nil, keyEquivalent: "")
      item.isEnabled = false
      menu.addItem(item)
    }
  }

  private func editActionsItem(titled title: String) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: #selector(pickEditActions), keyEquivalent: "")
    item.target = self
    return item
  }

  @objc private func pickAction(_ sender: NSMenuItem) {
    guard let name = sender.representedObject as? String else { return }
    runAction(name)
  }

  @objc private func pickEditActions() {
    editActions()
  }

  @objc private func showNextWorkingFrame() {
    guard let theme else { return }
    workingFrame += 1
    let image = StateDotImage.image(for: .running, theme: theme, frame: workingFrame)
    for row in workingRows { row.image = image }
  }
}

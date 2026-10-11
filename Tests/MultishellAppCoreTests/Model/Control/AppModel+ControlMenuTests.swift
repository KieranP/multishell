import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelControlMenuTests {
  @Test func theMenuIsListedAndAnItemChosenAsAClickWouldUnlessGreyedOut() async {
    let harness = Harness()
    harness.platform.menuItems = [
      PlatformMenuItem(path: ["View", "Enable Debug Tools"], isEnabled: true, isChecked: false),
      PlatformMenuItem(path: ["Edit", "Paste"], isEnabled: false, isChecked: false),
    ]

    let listed = await harness.stateSource.ask(.listMenuItems)
    let chosen = await harness.stateSource.ask(
      .performMenuItem(path: ["View", "Enable Debug Tools"])
    )
    let greyed = await harness.stateSource.ask(.performMenuItem(path: ["Edit", "Paste"]))
    let missing = await harness.stateSource.ask(.performMenuItem(path: ["Edit", "Frobnicate"]))

    #expect((listed?.outputObject as? [[String: Any]])?.count == 2)
    #expect(chosen == .done)
    #expect(greyed == .refused(.menuItemDisabled(path: "Edit > Paste")))
    #expect(missing == .refused(.noMenuItem(path: "Edit > Frobnicate")))
    #expect(harness.platform.performedMenuItems == [["View", "Enable Debug Tools"]])
  }
}

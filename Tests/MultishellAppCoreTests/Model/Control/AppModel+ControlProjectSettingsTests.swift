import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelControlProjectSettingsTests {
  @Test func theListHasEveryOwnSettingNullWhereItFollowsTheGlobalButNoTrustAnswers() async throws {
    let harness = Harness()

    let reply = try #require(
      await harness.messageSource.ask(
        .readProjectSettings(project: ControlID.project(harness.project.id), key: nil)
      )
    )

    #expect(reply.outputFields["autoStartAgent"] is NSNull)
    #expect(reply.outputFields["preCreateHook"] as? String == "")
    #expect(reply.outputFields["sharedHooks"] == nil)
  }

  @Test func aValueIsReadAsJSONWhereItParsesAndAsTextOtherwise() async throws {
    let harness = Harness()
    let project = ControlID.project(harness.project.id)

    #expect(
      await harness.messageSource.ask(
        .writeProjectSetting(project: project, key: "autoStartAgent", value: "true")
      ) == .done
    )
    #expect(
      await harness.messageSource.ask(
        .writeProjectSetting(project: project, key: "branchPrefix", value: "12")
      ) == .done
    )
    #expect(
      await harness.messageSource.ask(
        .writeProjectSetting(project: project, key: "iconTint", value: "3")
      ) == .done
    )

    let settings = harness.model.ownSettings(of: harness.project)
    #expect(settings.autoStartsAgent == true)
    #expect(settings.branchPrefix == "12")
    #expect(settings.iconTint == 3)
  }

  @Test func nullHandsASettingBackToTheGlobal() async {
    let harness = Harness()
    var settings = harness.model.ownSettings(of: harness.project)
    settings.autoStartsAgent = true
    harness.model.setSettings(settings, for: harness.project)

    let reply = await harness.messageSource.ask(
      .writeProjectSetting(
        project: ControlID.project(harness.project.id),
        key: "autoStartAgent",
        value: "null",
      )
    )

    #expect(reply == .done)
    #expect(harness.model.ownSettings(of: harness.project).autoStartsAgent == nil)
  }

  @Test func aValueTheSettingsWouldNotKeepAndTheTrustAnswersAreRefused() async {
    let harness = Harness()
    let project = ControlID.project(harness.project.id)

    #expect(
      await harness.messageSource.ask(
        .writeProjectSetting(project: project, key: "autoStartAgent", value: "maybe")
      )
        == .refused(.invalidValue(key: "autoStartAgent", value: "maybe"))
    )
    #expect(
      await harness.messageSource.ask(
        .writeProjectSetting(project: project, key: "worktreeSortOrder", value: "sideways")
      )
        == .refused(.invalidValue(key: "worktreeSortOrder", value: "sideways"))
    )
    #expect(
      await harness.messageSource.ask(
        .writeProjectSetting(project: project, key: "sharedHooks", value: "[]")
      )
        == .refused(.noSetting(key: "sharedHooks"))
    )
    #expect(
      await harness.messageSource.ask(.readProjectSettings(project: "p-00000000", key: nil))
        == .refused(.noProject(id: "p-00000000"))
    )
    #expect(harness.model.ownSettings(of: harness.project).autoStartsAgent == nil)
  }

  @Test func textIsKeptAsTypedWhereTheSettingTakesTextThoughItReadsAsJSON() async {
    let harness = Harness()
    let quoted = "\"/Applications/My App/setup\""

    let reply = await harness.messageSource.ask(
      .writeProjectSetting(
        project: ControlID.project(harness.project.id),
        key: "postCreateHook",
        value: quoted,
      )
    )

    #expect(reply == .done)
    #expect(harness.model.ownSettings(of: harness.project).postCreateHook == quoted)
  }

  @Test func nullIsRefusedWhereTheSettingHasNoGlobalToFollow() async {
    let harness = Harness()

    let reply = await harness.messageSource.ask(
      .writeProjectSetting(
        project: ControlID.project(harness.project.id),
        key: "preCreateHook",
        value: "null",
      )
    )

    #expect(reply == .refused(.invalidValue(key: "preCreateHook", value: "null")))
    #expect(harness.model.ownSettings(of: harness.project).preCreateHook == "")
  }
}

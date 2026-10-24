import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelControlGlobalSettingsTests {
  @Test func theListNamesSettingsByTheirStateFileKeys() async throws {
    let harness = Harness()

    let reply = try #require(await harness.messageSource.ask(.readGlobalSettings(key: nil)))

    let keys = Set(reply.outputFields.keys)
    for key in [
      "autoStartAgent", "defaultShell", "hookTimeoutSeconds", "themeID", "notifications.done",
      "agentFlags.claude",
    ] {
      #expect(keys.contains(key), "\(key)")
    }
    #expect(reply.outputFields["opensTerminalOnSelect"] as? Bool == true)
    #expect(reply.outputFields["preferredAgentID"] is NSNull)
  }

  @Test func aSettingWrittenGoesThroughTheSettingsWindowsSetter() async throws {
    let harness = Harness()

    #expect(
      await harness.messageSource.ask(.writeGlobalSetting(key: "autoStartAgent", value: "true"))
        == .done
    )
    #expect(
      await harness.messageSource.ask(.writeGlobalSetting(key: "preferredAgentID", value: "codex"))
        == .done
    )
    #expect(
      await harness.messageSource.ask(
        .writeGlobalSetting(key: "notifications.done", value: "true")
      )
        == .done
    )
    #expect(
      await harness.messageSource.ask(
        .writeGlobalSetting(key: "agentFlags.claude", value: "--verbose")
      ) == .done
    )
    #expect(
      await harness.messageSource.ask(
        .writeGlobalSetting(key: "worktreeSortOrder", value: "alphabetical")
      ) == .done
    )

    #expect(harness.model.workspace.autoStartsAgent)
    #expect(harness.model.workspace.preferredAgentID == "codex")
    #expect(harness.model.workspace.notificationPreference[.done])
    #expect(harness.model.workspace.agentFlags["claude"] == "--verbose")
    #expect(harness.model.workspace.worktreeSortOrder == .alphabetical)
    let read = await harness.messageSource.ask(.readGlobalSettings(key: "preferredAgentID"))
    #expect(read?.output == #""codex""#)
  }

  @Test func aValueTheKeyDoesNotTakeOrAnUnknownKeyIsRefusedAndChangesNothing() async {
    let harness = Harness()

    #expect(
      await harness.messageSource.ask(.writeGlobalSetting(key: "autoStartAgent", value: "maybe"))
        == .refused(.invalidValue(key: "autoStartAgent", value: "maybe"))
    )
    #expect(
      await harness.messageSource.ask(
        .writeGlobalSetting(key: "preferredAgentID", value: "nobody")
      )
        == .refused(.invalidValue(key: "preferredAgentID", value: "nobody"))
    )
    #expect(
      await harness.messageSource.ask(.writeGlobalSetting(key: "hookTimeoutSeconds", value: "-1"))
        == .refused(.invalidValue(key: "hookTimeoutSeconds", value: "-1"))
    )
    #expect(
      await harness.messageSource.ask(.readGlobalSettings(key: "nope"))
        == .refused(.noSetting(key: "nope"))
    )
    #expect(!harness.model.workspace.autoStartsAgent)
    #expect(harness.model.workspace.preferredAgentID == nil)
  }

  @Test func aPortStartBelow1024OrABlockSizeBelowOneIsRefused() async {
    let harness = Harness()

    for (key, value) in [("portBlockStart", "80"), ("portBlockSize", "0")] {
      #expect(
        await harness.messageSource.ask(.writeGlobalSetting(key: key, value: value))
          == .refused(.invalidValue(key: key, value: value))
      )
    }
    #expect(
      await harness.messageSource.ask(.writeGlobalSetting(key: "portBlockStart", value: "4000"))
        == .done
    )
    #expect(
      await harness.messageSource.ask(.writeGlobalSetting(key: "portBlockSize", value: "20"))
        == .done
    )
    #expect(harness.model.workspace.port(of: harness.feature.id) == 4020)
  }

  @Test func aShellOrEditorThePickersCannotNameIsRefused() async {
    let harness = Harness()

    for (key, value) in [("defaultShell", "zhs"), ("preferredEditorID", "vscod")] {
      #expect(
        await harness.messageSource.ask(.writeGlobalSetting(key: key, value: value))
          == .refused(.invalidValue(key: key, value: value))
      )
    }
    #expect(harness.model.workspace.preferredShellID == nil)
    #expect(harness.model.workspace.preferredEditorID == nil)
  }

  @Test func aFontFamilyThisMacLacksIsRefusedAndAnInstalledOneTaken() async {
    let harness = Harness()

    #expect(
      await harness.messageSource.ask(.writeGlobalSetting(key: "fontName", value: "Menloo"))
        == .refused(.invalidValue(key: "fontName", value: "Menloo"))
    )
    #expect(harness.model.workspace.appearance.terminalFontName == nil)
    #expect(
      await harness.messageSource.ask(.writeGlobalSetting(key: "fontName", value: "Menlo")) == .done
    )
    #expect(harness.model.workspace.appearance.terminalFontName == "Menlo")
  }

  @Test func aFontSizeOutsideItsSlidersRangeIsRefusedRatherThanClamped() async {
    let harness = Harness()
    let before = harness.model.workspace.appearance

    for (key, value) in [("fontSize", "40"), ("fontSize", "8"), ("uiFontSize", "19")] {
      #expect(
        await harness.messageSource.ask(.writeGlobalSetting(key: key, value: value))
          == .refused(.invalidValue(key: key, value: value))
      )
    }
    #expect(harness.model.workspace.appearance.terminalFontSize == before.terminalFontSize)
    #expect(harness.model.workspace.appearance.uiFontSize == before.uiFontSize)
    #expect(
      await harness.messageSource.ask(.writeGlobalSetting(key: "fontSize", value: "24")) == .done
    )
  }

  @Test func aShellPathTheLoginOrCustomEntryOrACatalogueEditorIsTaken() async {
    let harness = Harness()
    let accepted = [
      ("defaultShell", "/bin/sh"), ("defaultShell", "custom"), ("defaultShell", "login"),
      ("preferredEditorID", "vscode"), ("preferredEditorID", "custom"),
      ("preferredEditorID", "none"),
    ]

    for (key, value) in accepted {
      #expect(
        await harness.messageSource.ask(.writeGlobalSetting(key: key, value: value)) == .done
      )
    }
  }

  @Test func anEmptyValueClearsASettingThatMayBeNone() async {
    let harness = Harness()
    harness.model.setPreferredAgent("claude")

    #expect(
      await harness.messageSource.ask(.writeGlobalSetting(key: "preferredAgentID", value: ""))
        == .done
    )

    #expect(harness.model.workspace.preferredAgentID == nil)
  }

  @Test func anEmptyThemeIsRefusedSinceTheAppAlwaysShowsOne() async {
    let harness = Harness()
    let before = harness.model.workspace.appearance.themeID

    let reply = await harness.messageSource.ask(.writeGlobalSetting(key: "themeID", value: ""))

    #expect(reply == .refused(.invalidValue(key: "themeID", value: "")))
    #expect(harness.model.workspace.appearance.themeID == before)
  }

  @Test func theFileFontIsWrittenFromTheCommandLineAsTheTerminalsIs() async {
    let harness = Harness()

    #expect(
      await harness.messageSource.ask(.writeGlobalSetting(key: "fileFontName", value: "Menloo"))
        == .refused(.invalidValue(key: "fileFontName", value: "Menloo"))
    )
    #expect(
      await harness.messageSource.ask(.writeGlobalSetting(key: "fileFontName", value: "Menlo"))
        == .done
    )
    #expect(
      await harness.messageSource.ask(.writeGlobalSetting(key: "fileFontSize", value: "40"))
        == .refused(.invalidValue(key: "fileFontSize", value: "40"))
    )
    #expect(
      await harness.messageSource.ask(.writeGlobalSetting(key: "fileFontSize", value: "16"))
        == .done
    )
    #expect(harness.model.workspace.appearance.fileFontName == "Menlo")
    #expect(harness.model.workspace.appearance.fileFontSize == 16)
  }

  @Test func theUIFontFamilyIsWrittenFromTheCommandLine() async {
    let harness = Harness()

    #expect(
      await harness.messageSource.ask(.writeGlobalSetting(key: "uiFontName", value: "Menloo"))
        == .refused(.invalidValue(key: "uiFontName", value: "Menloo"))
    )
    #expect(
      await harness.messageSource.ask(.writeGlobalSetting(key: "uiFontName", value: "Menlo"))
        == .done
    )
    #expect(harness.model.workspace.appearance.uiFontName == "Menlo")
  }

  @Test func theFilesPanelIsNamedFilesOrGitOnTheCommandLineAsInThePanel() async {
    let harness = Harness()

    #expect(
      await harness.messageSource.ask(.writeGlobalSetting(key: "filesPanelMode", value: "git"))
        == .done
    )
    #expect(harness.model.workspace.filesPanelMode == .git)
    let read = await harness.messageSource.ask(.readGlobalSettings(key: "filesPanelMode"))
    #expect(read?.output == #""git""#)
    #expect(
      await harness.messageSource.ask(
        .writeGlobalSetting(key: "filesPanelMode", value: "modified")
      )
        == .refused(.invalidValue(key: "filesPanelMode", value: "modified")),
      "modified is a change scope",
    )
  }
}

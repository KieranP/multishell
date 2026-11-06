# Interface and terminal

Which test catches which breach of the rules for shortcuts, alerts, views, the
sidebar, settings windows, translation, the terminal engine, drops and
highlighting. Why each rule holds is in `design/`.

## What catches a breach of the rules

- **A shortcut's two spellings agree**: AppShortcutCatalogueTests. **The
  clipboard ones stay with the terminal**: GhosttyUnbindsTests, pinned against
  the config the engine was given.
- **Identifiers spelled in both Swift and the generated Info.plist still
  match**: InfoPlistTemplateTests. Nothing at build or run time notices these
  having parted.
- **The quit alert answers both keys under any language**: QuitAlertTests, with
  translated titles, since AppKit binds Escape by matching the English one.
- **A removal button keeps its red bezel and its Return**:
  DestructiveAlertTests. AppKit takes the key off at every layout and draws a
  default button in the accent colour. What a presented sheet draws is not
  testable here, so the suite holds the properties, bar macOS 27's alert button,
  which keeps no bezel colour: there the offscreen drawing is read.
- **Each override binds to its own setting**: AppModelSettingsBindingsTests, the
  override accessors all taking the same arguments and returning the same type.
- **A settings page outgrowing its fixed window**: ViewSettingsWindowTests lays
  each page out in a window never ordered in and holds it to the page column,
  `UIMetrics.settingsPageSize`.
- **The bound is absolute, not a margin**: Project Hooks' Create part under a
  repository file asking for trust, the tallest, measured 539 of 558 on
  2026-11-06, so a macOS that grows its controls fails this first, rightly.
  Appearance stays in: its font list is the machine's, but a picker is one row
  however long.
- **A page in parts is held part by part**: Project Hooks' three parts and
  Agents' Agent settings.
- **One part is exempt**: Agents' Agent hooks part reads the machine on appear,
  so its height is the developer's. Width is not checkable at all, a
  minimum-size measurement reporting where text wraps.
- **A tab strip that stops answering the wheel**: SidewaysWheelViewTests sends a
  synthesized vertical scroll to the overlay over a real scroller, spinning the
  run loop by hand, since `run(until:)` returns at once while it has no source.
  The same event handed straight to the scroller moves it by nothing, which is
  why the catcher exists. ViewSidewaysWheelTests holds the marked scroller to
  being the strip's and the catcher to sitting outside it. With the screen
  locked the scroller never moved and the four turns that expect it failed,
  where the run before passed them on the same AppUI code (2026-10-23).
- **A word on screen with no translation, or a translation nothing shows**:
  TranslationTests, one per catalogue (design/translation.md). The two files are
  a pair sharing TestScratch's TranslationCallSites, so a check added to one
  goes in the other. The app's also pins the shadowing the split rests on.
- **They also fail a multi-argument phrase that does not number its arguments
  and the C-string specifier**, a crash rather than a wrong word, and render
  every counted form singular and plural: a form whose format key does not name
  its own sub-dictionary answers with the raw format.
- **They expect a large number of call sites**, so a scan that lost the source
  tree fails rather than passes. They read the file as text as well as parsed,
  to catch an entry written twice or left blank, and compare the source
  catalogue with the built one byte for byte, so a skip-build run after a
  catalogue change fails instead of passing on what is no longer there.
- **The sidebar filter is not folded by the reader's alphabet**:
  SidebarListingTests reads the source, the current locale being process-wide
  and so not movable for one suite.
- **Over the board, the menu's Open in Editor and New Worktree name no
  worktree**, no row drawing as selected there: AppModelEditorTests and
  AppModel+NewWorktreeSheetTests+Request.
- **Open in Editor leaves the board and refuses a busy worktree, and neither an
  escaped rename nor Use Shell Title is undone by the commit after it**:
  AppModelEditorTests and AppModelTabRenamingTests, against the model rather
  than the field.
- **A frame handed another session's surface asks that session for focus**:
  SurfaceFrameTests.
- **A promised drop's reader is called off the main actor**, as AppKit calls it:
  PromisedDropCollectorTests. A reader written as if on main died at the first
  file of every promised drop, which only a real drag shows. The drag itself
  cannot be staged, a promise being fulfilled through a drag session this
  process never gets.
- **An item promising two files is not delivered on the first**:
  PromisedDropCollectorTests. **Its files paste in the order it names them**,
  whatever order they land in: PromisedDropTests.
- **A real surface is made only where its lifetime or libghostty's own callback
  is the question**, on `/bin/sleep` and in no window on screen: the runtime
  outliving it, a closed session staying silent, the pane monitor's two events,
  a clicked link reaching the delegate after libghostty's click returns,
  resolved in the pane's reported directory, a clipboard read made inside the
  user's key, click or Edit > Paste, and a surface's terminal memory, none once
  freed (GhosttySurfaceViewTests, GhosttyTerminalHostTests,
  GhosttyPaneEventMonitorTests, GhosttySurfaceViewClipboardTests,
  GhosttySurfaceViewMemoryTests). A failed expectation on a pane is read into a
  Bool first, as describing one trips over AppKit's cursors, null pointers in a
  test process. What libghostty is handed is otherwise tested as values: the
  key, modifier and mouse button mapping (GhosttyKeyInputTests,
  GhosttyModifiersTests, GhosttyMouseButtonTests), split surrogates
  (GhosttySurrogatePairingTests), the actions decoded
  (GhosttySurfaceEventTests), the launch's C strings
  (GhosttySurfaceLaunchTests), the clipboard and a program's reads of it
  (PanePasteboardTests, PastedImageFileTests, GhosttyClipboardContentsTests,
  GhosttyClipboardAnswerTests) and the unsafe paste question
  (GhosttyPasteConfirmationTests). Secure keyboard entry's balance against a
  fake system switch is GhosttySecureInputTests. Focus kept in step with the
  window is not: libghostty's own idea of it shows only on a live surface.
- **Under `make test` a surface's command never runs**: libghostty starts it
  through `/usr/bin/login`, setuid, which the sandbox refuses with `EPERM`. So a
  link clicked in a pane is tested from the event on (GhosttySurfaceEventTests,
  GhosttyLinkRuleTests, GhosttyLinkPathTests, GhosttyLinkClicksTests,
  GhosttyTerminalHostTests); that libghostty sends the event for a Cmd+click was
  seen by hand at Ghostty `ad97d33`.
- **A config file outliving its load, and the line a diagnostic names**:
  GhosttyLoadedConfigTests, against the real libghostty.
- **A find bar is its pane's own and ends with its pane**: AppModelFindTests.
- **The steps' engine spellings**: GhosttySearchActionsTests, the crossed next
  included; their shortcuts being taken from the surface and every unbind line
  accepted by the pinned engine are GhosttyUnbindsTests.
- **A CRLF Ghostty file read as one line, a config file name Ghostty reads and
  we do not, and an include left unfollowed**: GhosttyUserConfigTests.
- **Emptying the sidebar filter leaves the field up, and only closing hands the
  keyboard back**: AppModelSidebarFilterTests.
- **A project collapsed under the filter stays collapsed until the text changes,
  and its rows are read once it opens**: AppModelProjectExpansionTests and
  AppModel+StatusReadsTests+VisibleRows. SidebarViewTests holds the chevron to
  it by pixels.
- **A header badge ringed in the sidebar's colour**: WorktreeHeaderTests.
- **A row TextKit 2 lays out away from where its number says**:
  DiffDocumentViewTests and SplitDiffDocumentViewTests, over 10,000 rows jumped
  to from the end, the only check on an override Apple does not document
  (design/files/file-tabs.md). **A file tab painting outside its frame**:
  DiffDocumentViewTests+Clipping, by pixels.
- **A grammar bump whose query no longer compiles, or whose bundle is not
  found**: HighlightGrammarsTests, every grammar against its query.
- **A `<script>`, `<style>` or Svelte expression left plain or coloured in the
  wrong language**: HighlightInjectionsTests and its +Svelte, +ElementAttributes
  and +AttributeInjections suites, ElementBodyLanguageTests and
  SvelteBlockHeadTests. **A `>` or bare `&` in Svelte text leaving the rest of
  the file uncoloured**: SvelteGrammarInputTests and SyntaxHighlighterTests.
- **A Markdown fence left plain or coloured in a language it does not name, and
  nested fences overflowing the stack**: FencedCodeBlockTests. **A Markdown HTML
  block left plain, or a closing tag in a later block uncoloured**:
  HTMLBlocksTests. **An `<h1>` line the grammar folds into a paragraph left
  plain**: HeadingTagBlocksTests. **HTML parsed for removed rows holding only
  the Markdown between blocks**: SyntaxHighlighterTests.
- **A drag nothing takes or a drop refuses goes back between the neighbours it
  left, and one a drop took stays**: AppModelTabDragTests.
- **A segmented picker drawn only as wide as its labels**:
  ViewSegmentedAcrossRowTests.

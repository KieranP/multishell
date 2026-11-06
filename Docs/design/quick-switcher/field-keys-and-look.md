# Field, keys and look

The quick switcher's box over the window: the keys that open it, its scopes, the
AppKit field, its look and place, focus and closing, Return, scrolling and
VoiceOver. Newest at the bottom, above "Reviewed and left as is".

- **Cmd+P opens it on All, Shift+Cmd+P on Commands.** Cmd+K is what every Mac
  terminal clears the screen with, Ghostty included, and the people here come
  from those terminals; Cmd+P and Shift+Cmd+P are the editors' Go To and command
  palette. Ghostty's own palette sits on Shift+Cmd+P and an embedding never
  shows it, so the surface gives the key up, as it does Cmd+F.
- **One box with scopes, not two boxes.** The keys pick the scope it opens on;
  Tab and Shift+Tab step through All, Agents, Worktrees, Tabs, Files and
  Commands. A `>` typed into the empty field in All turns it to Commands, as an
  editor's palette takes it; one carried into All by Tab stays text. The key of
  the scope in view closes it, Cmd+P on All and Shift+Cmd+P on Commands; on any
  other scope either key goes to its own.
- **The pointer moving over a row selects it**, so one row is ever lit; it
  neither scrolls nor is announced, and rows moving under a still pointer as the
  text changes leave the selection. Only the selected row has a background.
- **It sits below the tab strip**, the header's height and a tab's under the
  window's top, so it covers neither the window's title nor its tabs.
- **The field is AppKit's.** SwiftUI's never shows a binding changed while it is
  edited, and the `>` rewrites the text; the arrows, Tab, Return and Escape go
  to the list through the field's own commands. Undo is off in it, because an
  undo changes the text without telling the delegate.
- **Its prompt is drawn over the field and hidden while an input method is
  composing**, the model's text being empty until the composition is confirmed.
  AppKit's own placeholder would hide itself, but setting it as the scope
  changes ends the field's editing, which closes the switcher.
- **Taking the keyboard selects the field's text, in the system's colour**, so
  the caret is put at the end: MonochromeThemeTests found the selection.
- **It wears the find bar's look**, a panel lifted under a hairline with the
  field in a well, under a `ui.quick_switcher` section of its own. The built-in
  themes take its colours from their find bar, and its fainter text and
  selection from their sidebar. Cost: a user's theme written before the section
  draws the switcher in its base theme's colours, as every new key falls back.
- **It closes when its field loses the keyboard to anything**, a find bar's
  field or a pane, and leaves the keyboard where it went. A sheet takes the
  window, not the field, which has the keyboard back when the sheet goes. A
  reconcile taking focus closes it too, the model's own guarantee without a
  window. Left up, it stayed drawn while keys went to whatever had taken them.
- **Backspace in an empty field goes back to All**, with Option or Command too,
  which undoes a `>` typed by mistake as an editor's palette does, though the
  `>` itself is gone.
- **The field takes back the model's text as each edit lands**, not on the next
  redraw: a key typed hard on a `>` would otherwise send the `>` again.
- **VoiceOver is told the row the arrows reach**, and only that, the keyboard
  staying in the field and typing heard as typing; an announcement, not checked
  with VoiceOver running.
- **Return chooses the row selected as the key lands**, so Down or a letter
  typed hard before it acts first. Only the arrows, the text, the scope and the
  row moved to going scroll the list; an arrow at either end brings its row back
  into view, and a report re-ranking it leaves the scroll where the user put it.

## Reviewed and left as is

Raised by reviews and settled; a review need not raise these again.

- **Escape over the Agents board or Debug Info leaving the keyboard on
  nothing.** No pane is in view to take it, and none had it before the switcher
  opened.
- **A background close taking focus closing the switcher.** That close takes the
  keyboard from whatever had it, switcher or not.
- **User themes written before `ui.quick_switcher`.** They fall back to the base
  theme's colours, as every new key does; the cost is above.
- **Cmd+W and the other menu shortcuts acting on the pane behind the open
  switcher.** They act on the window as they always do, and the switcher then
  closes as the pane takes the keyboard.
- **The field's font looked up by family on each redraw.** AppKit keeps the
  fonts it has made, and it is one lookup a redraw.
- **Cmd+Z replaying another field's typing into the switcher's.** Tested: it
  does not (`undoDoesNotReplayAnotherFieldsTypingIntoIt`).
- **A click on the switcher, or beside it, reaching the pane under it.** Tested:
  `hitTest` finds the switcher's own views there, never the pane
  (`aPaneUnderTheSwitcherIsNotWhatAClickOnItOrBesideItFinds`), so the pane
  monitor does not take the click.
- **The empty-field Backspace reading the field rather than the model.** While
  an input method composes, the model's text is still empty and the field's is
  not, so the model's answer would take Backspace from the composition.
- **A click on a row ending the field's editing before the click chooses.**
  Unproven: the test window, offscreen, cannot become key, so no test can send
  the click. It is under "Checked by hand" below.
- **The field's text set while it edits ending the editing and closing it.**
  Tested: the field keeps the keyboard and shows the text
  (`textTheModelSetsWhileTheFieldEditsIsShownWithoutClosingIt`).
- **A file open landing after the switcher opened again closing it.** The file
  asked for takes the keyboard as it opens, and anything taking the keyboard
  closes the switcher; the open takes milliseconds, a deleted file's a git read.
- **Cmd+P after Tab going to All rather than closing.** Each key names a scope,
  and the one in view is what it closes; the rule above says so.
- **A report re-ranking the rows in the instant between a redraw and Return.**
  Return then takes the new first row; taking the drawn one instead lost the
  user's own Down or letter typed in the same burst, which is the likelier.
- **The sidebar filter opened while launch ran losing the keyboard as it ends.**
  Its field is shown whether or not it is editing, and the model has no word of
  which; the switcher's, a rename's and a find bar's are known while they edit.
- **Launch's end skipping the seen-marking while one of those fields edits.**
  Unproven: launch selects nothing, and a Done in a pane in view is seen as it
  arrives, so no test found a pane the skipped marking would have cleared.
- **A rename field taken down without its blur, its id left set at launch's
  end.** Unproven: every way a rename ends found so far clears the id.
- **The scope bar's pills drawn by hand rather than with `SegmentFace`**
  (2026-11-04 review). SegmentFace rounds at 4 with an 8 pt inset and an 18 pt
  height; the pills round at 6 with 9 by 3. Taking it changes how they look, the
  user's call.

## Checked by hand

What tests cannot reach, to check in `make run` before a release:

- A click on a row chooses it, and moving the pointer over rows moves the one
  highlight; rows moving under a still pointer as the text changes do not.
- A click on a scope in the scope bar changes scope and leaves it open; a click
  ending the field's editing would close it instead.
- An input method's composition hides the prompt.
- VoiceOver announces each row the arrows reach, its path steps as a list.
- Cmd+P and Shift+Cmd+P open it from inside a terminal.
- The caret and field in a dark theme on a light system appearance.
- It sits below the tab strip and, in the shortest window, inside it.

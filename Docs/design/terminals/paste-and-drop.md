# Pasted and dropped files

What can be dropped or pasted on a shell. Newest at the bottom.

- **Files dropped on a terminal are pasted, never run.** A shell gets absolute
  quoted paths; an agent whose prompt reads mentions gets its prefix and paths
  relative to the directory its hooks report, else the session's.
- **One quoting for every shell**, a backslash and a `!` going outside the
  quotes: tcsh at a prompt expands a `!` even inside them, and fish reads `\\`
  and `\'` inside single quotes as escapes, so a name ending in a backslash
  carried the next name out of its quotes. The pane's shell is not known at the
  drop anyway, a fish typed at a zsh prompt being fish. Cost: nu, whose single
  quotes have no escape at all, still breaks on a name holding one.
- **A drop asks which agent a pane holds as its mark does**
  (agents/board-and-pane-rows.md). Cost: a tab opened as an agent keeps its id,
  so a drop after the agent quits still gets mentions.
- **Bracketed where the engine can frame it, trailing space, never a newline**,
  so the user reads what landed and presses Return themselves.
- **A name with a control character is left out altogether**, no quoting
  stopping a newline from pressing Return itself.
- **The pane takes focus only if still on screen when the files land**, since
  focus switches and saves the worktree's tab.
- **A copy macOS made for this app is asked for again through its promise**,
  into a directory of ours swept of old drops, because such a copy can sit
  somewhere the app can read and the pane's shell cannot.
- **Only a copy is refused**, a copy not being the file, recognised by the marks
  it carries rather than by reading it.
- **Costs**: a promised drop cannot be refused back to the drag, a copy macOS
  stops marking is pasted as a path again, and a file whose name a terminal
  would act on must be typed.
- **An item's file count is read as each file lands.** AppKit's `fileNames` is
  empty until the promise is called in, so counted up front, a legacy item
  naming several files counted as one and only the first was pasted.
- **Copied files paste as a drop words them**, single-quoted for any shell or an
  agent's mentions, and a name holding a control character left out, where the
  wrapper escaped them with backslashes. A program's clipboard read gets the
  quoted paths whatever the pane holds, a mention being for the user's prompt.
- **Files all left out paste nothing.** Finder puts a copied file's name beside
  it as text, so falling back to the text pasted the very name left out.
- **A paste libghostty judges unsafe is asked about in a sheet showing the
  text**, Paste taking Return as in Ghostty's app. That is a multi-line paste
  into a program without bracketed paste, macOS's bash 3.2 or a REPL; refused
  unasked, it typed nothing and said nothing.
- **A program's clipboard read or write libghostty would ask about is still
  refused unasked**, OSC 52 and kitty's protocol alike. Cost: a program that
  reads the clipboard that way gets nothing here.
- **One paste is asked about at a time**, another meanwhile refused, and one
  still waiting when its pane closes is refused before the surface goes.
- **A read with nothing to hand back is unavailable, not refused**, answered
  before libghostty's callback returns, as Ghostty's app does. Started first and
  refused after, an empty clipboard read as a denial to a kitty-protocol
  program.
- **An item's files are pasted in the order it names them**, a name it did not
  give going last. They land in whatever order its queue runs, so an item naming
  several pasted them out of order: `PromisedDropTests`.
- **A copied image pastes as a file saved to the drops directory**, one file for
  each item holding one, their paths or mentions typed as copied files' are,
  since a pane takes only text and an agent reads an image from a file.
- **Text beats an image**, as Office and Keynote put a picture of a copied
  selection beside its text, but empty or blank text does not hide the image.
  Cost: an app that puts an address as text beside a copied image pastes the
  address.
- **Saved once per copy**, known by the pasteboard's change count read before
  the image, so the same image pasted again types the same path. Each paste of
  the user's dates its directory today, the sweep going by that date, so the
  last path they typed resolves for a week; a program's read writes no date.
- **Only the user's own paste saves an image**, as libghostty reads the
  clipboard for one before the key, click or menu action returns, a middle click
  pasting by default, and for a program's OSC 52 or kitty read later, on its
  tick. Saving for those wrote a file the program could be refused, and handed
  it the path where `clipboard-read = allow`. A key `panes key` presses is not
  the user's, and of the binding actions only the Edit menu's Paste is marked.
  The mark is the app's, not a pane's, as an `all:` keybind pastes into every
  pane inside one key, in the order the panes were made, the keyed one among
  them.
- **A read outside the user's input reuses the file their paste saved**, so the
  read a program makes after a kitty paste event lists gets the image's path,
  quoted as a copied file's is for a program. Cost: an OSC 52 read allowed after
  the user pasted that copy gets it too, and a listing the program never reads
  after leaves its file for the sweep.
- **Copied files paste as quoted paths where the pane's session is gone**, as
  they did before agents got mentions for them.
- **The pasteboard is read only for a read a pane serves**, as a keybind pasting
  the selection clipboard would otherwise save an image for nothing.
- **A PNG, JPEG, GIF or WebP is written as it came**, in the first of them its
  item names, 3 ms for a 6 MB PNG; re-encoding a 12 MP JPEG as PNG took 877 ms
  and tripled it, and a GIF lost its animation. Each is written as it is read,
  so one image at a time is held.
- **Cost: an image that cannot be saved pastes nothing, and says nothing**, a
  full disk reading the same as a clipboard with no image.
- **Cost: a copy of many images is saved before the key returns**, each fetched
  and written on the main thread.
- **A menu action the command line performs is not the user's paste**, so
  `ui menu "Edit > Paste"` saves no image, as a `panes key` press does not.
- **A mention is relative to the directory the agent's hooks report**, kept
  outside what is drawn as a hook's cwd moves often, and compared resolved where
  the spellings differ, an agent's getcwd naming a symlink's target. Cost: after
  a worktree moves, the mention is absolute, which still resolves.
- **Cost: the image is read on the main thread inside libghostty's read**, so
  one Universal Clipboard has yet to bring from a phone holds the app until it
  arrives, as text did at a few bytes.
- **Cost: the path is this Mac's**, so a pane running ssh or a container is
  typed a path that does not exist there, as a dropped file is.
- **Cost: an image offered only as TIFF is made a PNG on the main thread**,
  inside libghostty's read, measured at 144 ms for a 5K one.
- **A review is handed over as a file in the drops directory and a mention of
  it**, bracketed, a trailing space and no newline, as a drop is: an agent with
  mentions gets its prefix and the absolute path, the directory being outside
  every worktree, and one without gets a sentence around the quoted path, a bare
  path saying nothing (files/review-comments.md).

## Reviewed and left as is

- **A word holding a newline is quoted as sh reads it, which tcsh refuses**
  (2026-11-12): tcsh wants a backslash before a newline inside single quotes,
  which every other shell keeps as text. A dropped name holding one is left out
  before quoting; Open in Editor on such a path under a tcsh login shell fails.

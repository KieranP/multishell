# Third party notices

Multishell is licensed under the GNU Affero General Public License v3.0; see
[LICENSE](LICENSE). It ships the software below, each under its own licence.

MIT asks that its notice travel with every copy of the code. That binds whoever
hands the copy over, so a dependency naming its own dependencies in its own
repository does not discharge it: nobody who receives `Multishell.app` sees
those repositories. What follows is the code that is actually in the app, found
by reading the built bundle rather than the dependency graph. Code that is
compiled in carries no file of its own, so its notice is reproduced here in
full; a file that ships with its licence beside it is pointed at instead of
copied. `make build` copies this file and `LICENSE` into
`Multishell.app/Contents/Resources/`, so both travel with the binary.

Adding a dependency means adding it here. `Docs/develop/dependencies.md` says
what each one is for; `Apps/macOS/Package.resolved` pins the versions.

## libghostty-spm

<https://github.com/Lakr233/libghostty-spm>. The app links its `GhosttyTerminal`
product, which is compiled into the executable. Its `GhosttyTheme` product,
which carries the iTerm2 colour schemes, is not linked and nothing of it ships.

```
MIT License

Copyright (c) 2026 @Lakr233

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### Ghostty

The `libghostty` binary inside that package, and the `xterm-ghostty` terminfo
entry in its resource bundle, are built from [Ghostty](https://ghostty.org). MIT
License, Copyright (c) 2024 Mitchell Hashimoto and the Ghostty contributors. The
package's `LICENSE` names only the repackager, so this line is the attribution
upstream is owed; its README states the same.

Ghostty's own bash and zsh integration scripts are GPLv3 and are not shipped.
The package ships its own MIT rewrite instead, and has a script that refuses GPL
text, which is what keeps this repository's AGPL from inheriting a GPL
obligation.

### bash-preexec

`GhosttyTerminal`'s resource bundle carries
`Ghostty/shell-integration/bash/bash-preexec.sh`, from
<https://github.com/rcaloras/bash-preexec>, MIT License, Copyright (c) 2017 Ryan
Caloras and contributors. It is not vendored in this repository, and its licence
ships beside it as
`GhosttyKit_GhosttyTerminal.bundle/Contents/Resources/Ghostty/shell-integration/bash/LICENSE-bash-preexec.md`,
so the notice already travels with the copy and is not repeated here.

## MSDisplayLink

<https://github.com/Lakr233/MSDisplayLink>, pinned at 2.2.0. A dependency of
libghostty-spm rather than one this repository declares, and compiled into the
executable, so its notice has to travel here.

```
MIT License

Copyright (c) 2024 Lakr Aream

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Agent marks

`Apps/macOS/Sources/Multishell/Resources/Marks/` holds hand-drawn marks for
Claude Code, Codex, Gemini CLI, GitHub Copilot and OpenCode, traced from each
vendor's own so a row reads at a glance. They are each vendor's trademark, not
Multishell's, and this project grants no rights over them. They identify the
agent the app is talking to and say nothing about endorsement.

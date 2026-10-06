# Two halves: what a Ghostty pane is told, and what the app is told through
# its socket. The app joins each half's included files as it writes the .zshrc.
autoload -Uz add-zsh-hook 2>/dev/null

# What a zsh pane tells Ghostty, whose own integration is off: prompt marks,
# a command's end, title, cursor and directory. Why each: terminals.md.
if [ "${TERM_PROGRAM-}" = ghostty ]; then
  # `cl=line` is one arrow per cell.
  typeset -g _multishell_prompt_mark=$'%{\e]133;A;cl=line\a%}'
  typeset -g _multishell_input_mark=$'%{\e]133;B\a%}'
  typeset -g _multishell_owes_command_end=0
  # A `-c` shell, as a hook runs in, never prompts and must print nothing.
  typeset -g _multishell_prompted=0

  # The cd hook runs inside a command and under its redirects, so it writes
  # to the terminal itself, as Ghostty's own script does; stdout without one.
  typeset -gi _multishell_tty_fd=1
  { zmodload zsh/system && [[ -w "${TTY-}" ]] \
    && sysopen -o cloexec -wu _multishell_tty_fd -- "$TTY" } 2>/dev/null || _multishell_tty_fd=1

  # Ghostty exports the user's shell-integration-features, `cursor:blink` and all.
  _multishell_has_feature() { [[ ",${GHOSTTY_SHELL_FEATURES-}," == *",$1"[,:]* ]]; }

  # include terminal-reports.zsh
  # include command-wrappers.zsh

  add-zsh-hook precmd _multishell_terminal_precmd
  add-zsh-hook precmd _multishell_prompt_click
  add-zsh-hook preexec _multishell_terminal_preexec
  # `cd x && cmd` runs cmd before any prompt reports the new directory.
  add-zsh-hook chpwd _multishell_report_directory

  # Chained, not set: a user's own keymap-select widget keeps running. Under
  # zsh's options, as err_return aborts add-zle-hook-widget.
  () {
    emulate -L zsh
    autoload -Uz add-zle-hook-widget 2>/dev/null || return 0
    add-zle-hook-widget keymap-select _multishell_keymap_cursor
    add-zle-hook-widget line-init _multishell_keymap_cursor
  }
fi

# What the app is told of a session: a command running, which agent it is,
# its end with a status and a time, and idle on the way out. agents.md.
if [ -n "${MULTISHELL_SESSION-}" ] && [ -n "${MULTISHELL_SOCKET-}" ]; then
  typeset -g _multishell_bin="__MULTISHELL_HELPER__"
  typeset -g _multishell_agents="__MULTISHELL_AGENTS__"
  typeset -g _multishell_ran=0
  typeset -g _multishell_started=0
  zmodload zsh/net/socket 2>/dev/null
  zmodload zsh/datetime 2>/dev/null

  # The path as a JSON string, once. Control characters as \u00XX: git allows
  # one in a parent directory, and a raw tab or newline lost every line.
  typeset -g _multishell_cwd=""
  () {
    local s="${${MULTISHELL_WORKTREE-}//\\/\\\\}" c
    s="${s//\"/\\\"}"
    if [[ "$s" != *[[:cntrl:]]* ]]; then _multishell_cwd="$s"; return; fi
    for c in "${(@s::)s}"; do
      [[ "$c" == [[:cntrl:]] ]] && printf -v c '\\u%04x' $(( #c ))
      _multishell_cwd+="$c"
    done
  }

  # include session-reports.zsh

  add-zsh-hook preexec _multishell_preexec
  add-zsh-hook precmd _multishell_precmd
  add-zsh-hook zshexit _multishell_zshexit
fi

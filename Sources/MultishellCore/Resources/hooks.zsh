# Ghostty moves the cursor to a click in the prompt only for a shell that
# names the sequences it takes back. The integration libghostty ships is not
# Ghostty's own — it is an MIT rewrite, Ghostty's being GPLv3 — and it names
# none, so the claim has to come from here. `cl=line` is one arrow per cell,
# which zsh's line editor honours.
#
# It rides at the front of PS1 rather than being printed, because it has to be
# the last prompt-start mark the terminal sees: that integration prints a plain
# one from a precmd of its own, registered after ours and so run after it, and
# a plain mark is how a terminal is told the shell claims nothing. PS1 is
# expanded once every precmd has run, and again on every redraw.
#
# The input mark goes on the end of PS1 with it, where that integration also
# puts one when it is loaded; either sees the other's. A claim over text no
# mark calls input is worse than no claim: Ghostty takes the click, counts no
# cells to cross, and answers with nothing, so the click is swallowed.
#
# Output start is printed, and goes with them. That integration writes this
# mark too, and writing it twice changes nothing; it matters where the
# integration is not loaded, when the claim would otherwise stand for the whole
# session and Ghostty would take every click as one in a prompt, including the
# clicks a program drawing in the same screen is waiting for.
if [ "${TERM_PROGRAM-}" = ghostty ]; then
  typeset -g _multishell_prompt_mark=$'%{\e]133;A;cl=line\a%}'
  typeset -g _multishell_input_mark=$'%{\e]133;B\a%}'
  _multishell_prompt_click() {
    # A prompt that does not take `%{ %}` would show the escape instead.
    [[ -o prompt_percent ]] || return 0
    [[ "$PS1" == *"$_multishell_prompt_mark"* ]] || PS1="$_multishell_prompt_mark$PS1"
    [[ "$PS1" == *$'\e]133;B\a'* ]] && return 0
    # A trailing bare `%` would join the mark's `%{` into a literal percent.
    [[ "$PS1" == *[^%]% || "$PS1" == % ]] && PS1="$PS1%"
    PS1="$PS1$_multishell_input_mark"
  }
  _multishell_prompt_output() { print -n -- $'\e]133;C\a'; }
  autoload -Uz add-zsh-hook 2>/dev/null
  add-zsh-hook precmd _multishell_prompt_click
  add-zsh-hook preexec _multishell_prompt_output
fi

if [ -n "${MULTISHELL_SESSION-}" ] && [ -n "${MULTISHELL_SOCKET-}" ]; then
  typeset -g _multishell_bin="__MULTISHELL_HELPER__"
  typeset -g _multishell_ran=0
  typeset -g _multishell_started=0
  zmodload zsh/net/socket 2>/dev/null
  zmodload zsh/datetime 2>/dev/null
  # $1 is the JSON line; the rest is the helper's argv for the fallback.
  _multishell_send() {
    local line="$1"; shift
    if (( ${+builtins[zsocket]} )); then
      local fd
      zsocket "$MULTISHELL_SOCKET" 2>/dev/null || return 0
      fd=$REPLY
      print -r -u $fd -- "$line"
      exec {fd}>&-
    elif [ -x "$_multishell_bin" ]; then
      "$_multishell_bin" "$@" >/dev/null 2>&1
    fi
  }
  _multishell_json() {
    local cwd="${MULTISHELL_WORKTREE//\\/\\\\}"
    cwd="${cwd//\"/\\\"}"
    print -r -- "{\"v\":1,\"state\":\"$1\",\"session\":\"$MULTISHELL_SESSION\",\"cwd\":\"$cwd\"$2}"
  }
  # Both reports run inline: a fast command's finished must not overtake
  # its started, and a fast close must not skip either.
  _multishell_preexec() {
    _multishell_ran=1
    _multishell_started=${EPOCHREALTIME:-$SECONDS}
    _multishell_send "$(_multishell_json running ",\"pid\":$$")" command-started --pid $$
  }
  _multishell_precmd() {
    local e=$?
    [ "$_multishell_ran" = 1 ] || return
    _multishell_ran=0
    local d state
    # Integer milliseconds, the point written by hand: `%f` takes the locale's
    # separator. Clamped, or a clock stepped back writes `0.-234`; terminals.md.
    local -i _multishell_ms=$(( (${EPOCHREALTIME:-$SECONDS} - _multishell_started) * 1000 ))
    (( _multishell_ms < 0 )) && _multishell_ms=0
    printf -v d '%d.%03d' $(( _multishell_ms / 1000 )) $(( _multishell_ms % 1000 ))
    if [ "$e" -eq 0 ] || [ "$e" -gt 128 ]; then state=done; else state=error; fi
    _multishell_send "$(_multishell_json $state ",\"duration\":$d")" command-finished --exit "$e" --duration "$d"
  }
  # `exit` runs preexec but never the next precmd, so clear on the way out.
  _multishell_zshexit() { _multishell_send "$(_multishell_json idle "")" state idle; }
  autoload -Uz add-zsh-hook 2>/dev/null
  add-zsh-hook preexec _multishell_preexec
  add-zsh-hook precmd _multishell_precmd
  add-zsh-hook zshexit _multishell_zshexit
fi

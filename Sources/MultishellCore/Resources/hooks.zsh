if [ -n "$MULTISHELL_SESSION" ] && [ -n "$MULTISHELL_SOCKET" ]; then
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
    printf -v d '%.3f' $(( ${EPOCHREALTIME:-$SECONDS} - _multishell_started ))
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

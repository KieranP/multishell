# The functions init.zsh installs where the app gave the session a socket:
# what it is told of each command. Docs/design/agents.md.

# $1 is the JSON line; the rest is the helper's argv for the fallback.
_multishell_send() {
  local line="$1"; shift
  if (( ${+builtins[zsocket]} )); then
    local fd
    zsocket "$MULTISHELL_SOCKET" 2>/dev/null || return 0
    fd=$REPLY
    print -r -u $fd -- "$line"
    exec {fd}>&-
  elif [[ -x "$_multishell_bin" ]]; then
    "$_multishell_bin" "$@" >/dev/null 2>&1
  fi
}

# A state and the JSON fields after it, then the helper's argv. `shell`
# marks these as the integration's own; see Docs/design/agents.md.
_multishell_report_state() {
  local state=$1 fields=$2
  shift 2
  _multishell_send "{\"v\":1,\"state\":\"$state\",\"session\":\"$MULTISHELL_SESSION\",\"cwd\":\"$_multishell_cwd\",\"shell\":true$fields}" "$@"
}

# Both reports run inline: a fast command's finished must not overtake
# its started, and a fast close must not skip either.
_multishell_preexec() {
  # Words counted from 1 whatever the user set; ksh_arrays lost the command.
  emulate -L zsh
  _multishell_ran=1
  _multishell_started=${EPOCHREALTIME:-$SECONDS}

  # The program being started, sent only where it is an agent: the
  # expanded line, its words, past any prefix. Docs/design/agents.md.
  local -a parts=(${(z)${2:-$1}})
  local -i i=1
  while (( i <= $#parts )) && [[ ${parts[i]} == (*=*|command|env|exec) ]]; do
    (( i++ ))
  done
  local cmd=${parts[i]:t} fields=",\"pid\":$$"
  if [[ -n "$cmd" && " $_multishell_agents " == *" $cmd "* ]]; then
    fields+=",\"command\":\"$cmd\""
  else
    cmd=""
  fi

  _multishell_report_state running "$fields" command-started --pid $$ --command "$cmd"
}

_multishell_precmd() {
  local e=$?
  # zsh's options, not the user's: under err_exit a failed send ended the shell.
  emulate -L zsh
  # Status 0: a hook returning 1 ends the shell under the user's err_exit.
  (( _multishell_ran )) || return 0
  _multishell_ran=0

  # Integer milliseconds, the point written by hand: `%f` takes the locale's
  # separator. Clamped, or a clock stepped back writes `0.-234`; terminals.md.
  local -i ms=$(( (${EPOCHREALTIME:-$SECONDS} - _multishell_started) * 1000 ))
  (( ms < 0 )) && ms=0
  local duration state=error
  printf -v duration '%d.%03d' $(( ms / 1000 )) $(( ms % 1000 ))
  (( e == 0 || e > 128 )) && state=done

  _multishell_report_state $state ",\"duration\":$duration" \
    command-finished --exit "$e" --duration "$duration"
  return 0
}

# `exit` runs preexec but never the next precmd, so clear on the way out. A
# subshell's `exit` runs this too, while the command it is part of still runs.
_multishell_zshexit() {
  emulate -L zsh
  (( ZSH_SUBSHELL )) && return 0
  _multishell_report_state idle "" state idle --shell true
  return 0
}

# The functions init.zsh installs where the app gave the session a socket:
# what it is told of each command. Docs/design/agents/reports-and-hooks.md.

# $1 is the JSON line; the rest is the helper's argv for the fallback.
_multishell_send() {
  local line="$1"; shift
  if (( ${+builtins[zsocket]} )); then
    # zsocket answers in REPLY, which is the user's: a `read` leaves its line there.
    local fd REPLY
    zsocket "$MULTISHELL_SOCKET" 2>/dev/null || return 0
    fd=$REPLY
    print -r -u $fd -- "$line"
    exec {fd}>&-
  elif [[ -x "$_multishell_bin" ]]; then
    "$_multishell_bin" "$@" >/dev/null 2>&1
  fi
}

# A state and the JSON fields after it, then the helper's argv. `shell` marks
# these as the integration's own; see Docs/design/agents/board-and-pane-rows.md.
_multishell_report_state() {
  local state=$1 fields=$2
  shift 2
  _multishell_send "{\"v\":1,\"state\":\"$state\",\"session\":\"$MULTISHELL_SESSION\",\"cwd\":\"$_multishell_cwd\",\"shell\":true$fields}" "$@"
}

# `exec zsh` and omz's reload put a new zsh in the pane that reads only the
# user's files, so ZDOTDIR is ours again for that one line.
_multishell_replaces_itself() {
  [[ $1 == omz && $2 == reload ]] && return 0
  [[ $1 == exec ]] || return 1
  shift
  while [[ ${1-} == (-*|*=*) ]]; do shift; done
  # The words are unexpanded; `exec "$SHELL"` is the reload pyenv and nvm document.
  local program=${(Q)1-}
  case $program in
    ('$SHELL'|'${SHELL}') program=${SHELL-} ;;
  esac
  [[ ${program:t} == zsh ]] || return 1
  shift
  # Only an interactive zsh reads our .zshrc, which hands ZDOTDIR back.
  local word
  for word in "$@"; do
    [[ $word == (-i|-l|-il|-li|--login|--interactive) ]] || return 1
  done
}

# A shell exec'd to sit at its prompt keeps the pid and reports nothing, so a
# start sent for it held the pane Running until it closed. One given a command runs it.
_multishell_execs_a_shell_at_its_prompt() {
  [[ $1 == exec ]] || return 1
  shift
  # exec's own `-a` takes the name the program is given.
  while [[ ${1-} == (-*|*=*) ]]; do
    [[ $1 == (-a|-[^-]*a) ]] && shift
    (( $# )) && shift
  done
  local program=${(Q)1-}
  case $program in
    ('$SHELL'|'${SHELL}') program=${SHELL-} ;;
  esac
  [[ ${program:t} == (zsh|bash|sh|dash|ksh|fish|tcsh|csh|nu) ]] || return 1
  shift
  # fish's -C is a line run before its prompt, not a command in place of one.
  while (( $# )); do
    case $1 in
      (-c|-[^-]*c*|--command|--command=*|--commands) return 1 ;;
      (-o|+o|-O|+O|-C|--rcfile|--init-file|--init-command|--emulate) shift ;;
      ([-+]*) ;;
      (*) return 1 ;;
    esac
    (( $# )) && shift
  done
  return 0
}

# Both reports run inline: a fast command's finished must not overtake
# its started, and a fast close must not skip either.
_multishell_preexec() {
  # Words counted from 1 whatever the user set; ksh_arrays lost the command.
  emulate -L zsh
  # $3, not $2: zsh cuts $2 at 80 characters, dropping the words past the cut.
  local -a parts=(${(z)${3:-$1}})
  # The new zsh never finishes this line, so it starts nothing: a start left
  # the pane Running until the next command ended.
  if [[ -n ${_multishell_self_zdotdir-} ]] && _multishell_replaces_itself "${parts[@]}"; then
    _multishell_lends_zdotdir=1
    export ZDOTDIR=$_multishell_self_zdotdir
    return 0
  fi
  _multishell_execs_a_shell_at_its_prompt "${parts[@]}" && return 0
  _multishell_ran=1
  _multishell_started_at=${EPOCHREALTIME:-$SECONDS}

  # The program being started, sent only where it is an agent: the expanded
  # line, its words, past any prefix. Docs/design/agents/board-and-pane-rows.md.
  local -i i=1
  while (( i <= $#parts )) && [[ ${parts[i]} == (*=*|command|env|exec) ]]; do
    (( i++ ))
  done
  local command_word=${parts[i]:t} fields=",\"pid\":$$"
  if [[ -n "$command_word" && " $_multishell_agents " == *" $command_word "* ]]; then
    fields+=",\"command\":\"$command_word\""
  else
    command_word=""
  fi

  _multishell_report_state running "$fields" command-started --pid $$ --command "$command_word"
}

_multishell_precmd() {
  local exit_code=$?
  # zsh's options, not the user's: under err_exit a failed send ended the shell.
  emulate -L zsh
  # The line that was to replace the shell did not: ZDOTDIR goes back to the user.
  if (( ${_multishell_lends_zdotdir:-0} )); then
    _multishell_lends_zdotdir=0
    if [[ -n ${MULTISHELL_USER_ZDOTDIR-} ]]; then
      export ZDOTDIR=$MULTISHELL_USER_ZDOTDIR
    else
      unset ZDOTDIR
    fi
  fi
  # Status 0: a hook returning 1 ends the shell under the user's err_exit.
  (( _multishell_ran )) || return 0
  _multishell_ran=0

  # Integer ms, the point written by hand: `%f` takes the locale's separator.
  # Clamped, or a clock set back gives `0.-234`; terminals/shell-integration.md.
  local -i ms=$(( (${EPOCHREALTIME:-$SECONDS} - _multishell_started_at) * 1000 ))
  (( ms < 0 )) && ms=0
  local duration state=error
  printf -v duration '%d.%03d' $(( ms / 1000 )) $(( ms % 1000 ))
  (( exit_code == 0 || exit_code > 128 )) && state=done

  _multishell_report_state $state ",\"duration\":$duration" \
    command-finished --exit "$exit_code" --duration "$duration"
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

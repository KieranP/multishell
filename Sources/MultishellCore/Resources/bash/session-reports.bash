# The functions init.bash installs in a session: what the app is told of each
# command through the helper. Docs/design/agents/reports-and-hooks.md.

# A line the relay would carry, `kind first second`, as the helper's own argv.
_multishell_run_helper() {
  case "$1" in
    command-started) "$_multishell_bin" command-started --pid "$2" --command "$3" ;;
    command-finished) "$_multishell_bin" command-finished --exit "$2" --duration "$3" ;;
  esac
}

# A relay that fails, an older helper or a crash, leaves lines in the pipe, so
# they go a helper each from here; Docs/design/terminals/shell-integration.md.
_multishell_relay_or_inline() {
  "$_multishell_bin" relay --pid $$ && return
  trap '' HUP TSTP TTIN TTOU
  local kind first second began
  while :; do
    began=$SECONDS
    if IFS=' ' read -r -t 1 kind first second; then
      _multishell_run_helper "$kind" "$first" "$second"
    # bash 3.2 gives a timeout EOF's status; only a timeout lets a second pass.
    elif [ "$SECONDS" = "$began" ] || ! kill -0 $$ 2>/dev/null; then
      return
    fi
  done
}

# bash 5.3 captures output without a fork; older ones pay one per report.
if (( BASH_VERSINFO[0] > 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] >= 3) )); then
  _multishell_read_pipe_trap='theirs=${ trap -p PIPE; }'
else
  _multishell_read_pipe_trap='theirs="$(trap -p PIPE)"'
fi

# SIGPIPE from a gone relay would kill the shell, so it is ignored around the
# write and the trap standing then is put back; a failure sends the rest inline.
_multishell_relayed() {
  [ "$_multishell_relay" = 1 ] || return 1
  local failed=0 theirs
  eval "$_multishell_read_pipe_trap"
  trap '' PIPE
  printf '%s\n' "$1" 2>/dev/null >&62 || failed=1
  eval "${theirs:-trap - PIPE}"
  [ "$failed" = 0 ] && return 0

  _multishell_relay=0
  exec 62>&-
  return 1
}

# Down one pipe or inline, never in the background: session-reports.zsh says why.
_multishell_command_started() {
  _multishell_ran=1
  _multishell_started_at=${EPOCHREALTIME:-$SECONDS}
  _multishell_output_mark

  # The program being started, sent only where it is an agent: the words
  # of the line, past any prefix. Docs/design/agents/board-and-pane-rows.md.
  local line="$1" command_word="" quote=""
  while [ -n "$line" ]; do
    command_word="${line%% *}"
    # A quoted value holding a space spans words, skipped to its closing quote.
    if [ -n "$quote" ]; then
      case "$command_word" in (*"$quote"*) quote="" ;; esac
    else
      case "$command_word" in
        ""|command|env|exec) ;;
        *=\"*) case "${command_word#*=\"}" in (*\"*) ;; (*) quote='"' ;; esac ;;
        *=\'*) case "${command_word#*=\'}" in (*\'*) ;; (*) quote="'" ;; esac ;;
        *=*) ;;
        *) break ;;
      esac
    fi
    command_word=""
    case "$line" in
      *" "*) line="${line#* }" ;;
      *) line="" ;;
    esac
  done
  command_word="${command_word##*/}"
  case " $_multishell_agents " in
    (*" $command_word "*) ;;
    (*) command_word="" ;;
  esac

  _multishell_relayed "command-started $$ $command_word" ||
    _multishell_run_helper command-started $$ "$command_word" >/dev/null 2>&1
}

# A bare `trap ... DEBUG` replaces the one .bashrc installed, silencing
# Atuin and bash-preexec. Theirs is kept, quoted as `trap -p` prints it.
_multishell_capture_debug() {
  local body
  case "$1" in
    "trap -- "*" DEBUG")
      body="${1#trap -- }"
      body="${body% DEBUG}"
      # `trap -p` prints the body quoted for re-input. The quotes come off
      # here, or `eval` runs the whole of it as one word and finds nothing.
      eval "_multishell_prior_debug=$body" ;;
    *) _multishell_prior_debug="" ;;
  esac
}

# bash-preexec, which Atuin ships, installs its trap at the first prompt,
# long after this file ran. Whether ours still stands is asked at each one.
_multishell_owns_debug_or_saves_theirs() {
  case "$_multishell_seen_debug" in
    *_multishell_debug*) return 0 ;;
  esac
  _multishell_capture_debug "$_multishell_seen_debug"
  return 1
}

# `exec bash` puts a new bash in the pane that reads none of ours, so the plain
# forms start it as a tab's is; a redirection or another flag runs as typed.
_multishell_reexec_if_replacing_itself() {
  local -a words
  read -r -a words <<< "$1"
  case "${words[1]-}" in bash | */bash) ;; *) return 0 ;; esac
  local word
  for word in "${words[@]:2}"; do
    case "$word" in -i | -l | -il | -li | --login) ;; *) return 0 ;; esac
  done
  # The words are as typed, unexpanded; a failed exec in this trap ends the shell.
  local target="${words[1]}"
  case "$target" in */*) ;; *) target="$(type -P "$target")" ;; esac
  [ -x "$target" ] || return 0
  builtin exec "$target" --init-file "$_multishell_init_file" -i
}

_multishell_debug() {
  # Before theirs is called, so their trap never sees our own prompt
  # functions: without us it would not have.
  case "$BASH_COMMAND" in _multishell_*) return 0 ;; esac
  # Theirs sees no arguments of ours, and `:` puts the user's `$_` back for it.
  # Its status is ours to return: under extdebug a non-zero one skips the command.
  local _multishell_their_status=0
  if [ -n "$_multishell_prior_debug" ]; then
    local last_argument="${1-}"
    set --
    : "$last_argument"
    eval "$_multishell_prior_debug"
    _multishell_their_status=$?
  fi
  # bash has no cd hook, so the next command finds the change; only once a
  # prompt has reported, which it does only in a Ghostty pane.
  case "${_multishell_last_reported_directory-$PWD}" in "$PWD") ;; *) _multishell_report_directory ;; esac

  [ "$_multishell_armed" = 1 ] || return $_multishell_their_status
  # A completion or a `bind -x` widget, fzf's Ctrl-R, runs before the line does.
  [ -n "${COMP_LINE-}" ] && return $_multishell_their_status
  [ -n "${READLINE_POINT-}" ] && return $_multishell_their_status
  # bash-preexec adds its prompt entry after our arm, at the first prompt.
  case "$BASH_COMMAND" in __bp_*) return $_multishell_their_status ;; esac
  case "$BASH_COMMAND" in "exec "*) _multishell_reexec_if_replacing_itself "$BASH_COMMAND" ;; esac
  _multishell_armed=0
  _multishell_command_started "$BASH_COMMAND"
  return $_multishell_their_status
}

_multishell_precmd() {
  local exit_code=$?
  # An empty Enter runs nothing, so the arm would live on into the user's
  # own PROMPT_COMMAND entry and report it as a command.
  _multishell_armed=0

  if [ "$_multishell_ran" = 1 ]; then
    _multishell_ran=0
    # bash 3.2 has no EPOCHREALTIME; SECONDS is enough. Cut at either
    # separator: EPOCHREALTIME writes the locale's, and a comma broke this.
    local now=${EPOCHREALTIME:-$SECONDS}
    now=${now%%[.,]*}
    local began=${_multishell_started_at%%[.,]*}
    local seconds=$(( now - began ))
    [ "$seconds" -ge 0 ] || seconds=0
    _multishell_relayed "command-finished $exit_code $seconds" ||
      _multishell_run_helper command-finished "$exit_code" "$seconds" >/dev/null 2>&1
  fi

  # bash does not restore $? between PROMPT_COMMAND entries, and a prompt
  # showing the last exit code reads whatever we left.
  return $exit_code
}

# The left of `&&`, where errexit does not reach: the status the precmd hands
# back for the user's entries ended a `set -e` shell at every prompt after a failure.
_multishell_precmd_entry='_multishell_precmd && :'

# A .bashrc sourced again puts its prepended entry before ours, which then reads
# that entry's 0; ours goes back in front, as zsh's precmd hook does.
# bash-preexec's entry stays first, where it reads PIPESTATUS before anything runs.
_multishell_keep_precmd_first() {
  case "${PROMPT_COMMAND[0]-}" in
    "$_multishell_precmd_entry" | "$_multishell_precmd_entry"$'\n'* | __bp_precmd_invoke_cmd*)
      return 0 ;;
  esac
  export -n PROMPT_COMMAND
  # Before 5.1 bash runs element 0 alone, so ours goes into it, not beside it.
  if [ "${#PROMPT_COMMAND[@]}" -gt 1 ] &&
    (( BASH_VERSINFO[0] > 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] >= 1) )); then
    PROMPT_COMMAND=("$_multishell_precmd_entry" "${PROMPT_COMMAND[@]//$_multishell_precmd_entry/:}")
  else
    # Copied first: bash 3.2 substitutes within an array element as if it were empty.
    local first="${PROMPT_COMMAND[0]}"
    PROMPT_COMMAND[0]="$_multishell_precmd_entry"$'\n'"${first//$_multishell_precmd_entry/:}"
  fi
}

_multishell_arm() {
  _multishell_keep_precmd_first
  _multishell_armed=1
}

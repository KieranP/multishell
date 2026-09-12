# Multishell bash integration, for this app's terminals only: --init-file
# points here, so reproduce a login shell's startup, then add the hooks.
if [ -f /etc/profile ]; then . /etc/profile; fi
_multishell_profiled=0
for _multishell_profile in "$HOME/.bash_profile" "$HOME/.bash_login" "$HOME/.profile"; do
  if [ -f "$_multishell_profile" ]; then . "$_multishell_profile"; _multishell_profiled=1; break; fi
done
unset _multishell_profile
# A login shell reads no .bashrc of its own; the usual profile ends by sourcing
# it. Reading it here as well ran it twice, doubling anything prepended.
if [ "$_multishell_profiled" = 0 ] && [ -f "$HOME/.bashrc" ]; then . "$HOME/.bashrc"; fi
unset _multishell_profiled

if [ -n "${MULTISHELL_SESSION-}" ] && [ -x "__MULTISHELL_HELPER__" ]; then
  _multishell_bin="__MULTISHELL_HELPER__"
  _multishell_ran=0
  _multishell_armed=0
  _multishell_started=0
  # Ghostty writes no marks for bash, so all three come from here and ride
  # with the hooks; see docs/design/terminals.md.
  if [ "${TERM_PROGRAM-}" = ghostty ]; then _multishell_marks=1; else _multishell_marks=0; fi
  # Inline, not in the background, for the same reasons as the zsh body.
  _multishell_command_started() {
    _multishell_ran=1
    _multishell_started=${EPOCHREALTIME:-$SECONDS}
    if [ "$_multishell_marks" = 1 ]; then printf '\033]133;C\007'; fi
    "$_multishell_bin" command-started --pid $$ >/dev/null 2>&1
  }
  # A bare `trap ... DEBUG` replaces the one .bashrc installed, silencing
  # Atuin and bash-preexec. Theirs is kept, quoted as `trap -p` prints it.
  _multishell_prior_debug="$(trap -p DEBUG)"
  case "$_multishell_prior_debug" in
    "trap -- "*" DEBUG")
      _multishell_prior_debug="${_multishell_prior_debug#trap -- }"
      _multishell_prior_debug="${_multishell_prior_debug% DEBUG}" ;;
    *) _multishell_prior_debug="" ;;
  esac
  _multishell_debug() {
    # Before theirs is called, so their trap never sees our own prompt
    # functions: without us it would not have.
    case "$BASH_COMMAND" in _multishell_*) return 0 ;; esac
    if [ -n "$_multishell_prior_debug" ]; then eval "$_multishell_prior_debug"; fi
    [ "$_multishell_armed" = 1 ] || return 0
    [ -n "${COMP_LINE-}" ] && return 0
    _multishell_armed=0
    _multishell_command_started
  }
  _multishell_precmd() {
    local e=$?
    if [ "$_multishell_ran" = 1 ]; then
      _multishell_ran=0
      # bash 3.2 has no EPOCHREALTIME; SECONDS is enough. Cut at either
      # separator: EPOCHREALTIME writes the locale's, and a comma broke this.
      local now=${EPOCHREALTIME:-$SECONDS}
      now=${now%%[.,]*}
      local began=${_multishell_started%%[.,]*}
      local d=$(( now - began ))
      [ "$d" -ge 0 ] || d=0
      "$_multishell_bin" command-finished --exit "$e" --duration "$d" >/dev/null 2>&1
    fi
  }
  _multishell_arm() { _multishell_armed=1; }
  # Prompt start printed, input start on the end of PS1, which is why this
  # runs last of all; see docs/design/terminals.md.
  _multishell_prompt_marks() {
    [ "$_multishell_marks" = 1 ] || return 0
    printf '\033]133;A;cl=line\007'
    [ -n "${PS1-}" ] || return 0
    case "$PS1" in
      *'133;B'*) ;;
      *) PS1="$PS1"'\[\e]133;B\a\]' ;;
    esac
  }
  trap '_multishell_debug' DEBUG
  case "${PROMPT_COMMAND-}" in
    *_multishell_precmd*) ;;
    *)
      if [[ "$(declare -p PROMPT_COMMAND 2>/dev/null)" == "declare -a"* ]]; then
        PROMPT_COMMAND=(
          _multishell_precmd "${PROMPT_COMMAND[@]}" _multishell_prompt_marks _multishell_arm)
      else
        # Newlines, not `;`: a user value ending in a separator composed to
        # `;;`, which bash refuses, so none of the three ran.
        PROMPT_COMMAND="_multishell_precmd
${PROMPT_COMMAND-}
_multishell_prompt_marks
_multishell_arm"
      fi ;;
  esac
fi

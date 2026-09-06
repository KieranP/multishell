# Multishell bash integration, for this app's terminals only. bash was
# launched with --init-file pointing here, so reproduce a login shell's
# startup, then add the command-status hooks.
if [ -f /etc/profile ]; then . /etc/profile; fi
for _multishell_profile in "$HOME/.bash_profile" "$HOME/.bash_login" "$HOME/.profile"; do
  if [ -f "$_multishell_profile" ]; then . "$_multishell_profile"; break; fi
done
unset _multishell_profile
# In case the profile did not already source it.
if [ -f "$HOME/.bashrc" ]; then . "$HOME/.bashrc"; fi

if [ -n "$MULTISHELL_SESSION" ] && [ -x "__MULTISHELL_HELPER__" ]; then
  _multishell_bin="__MULTISHELL_HELPER__"
  _multishell_ran=0
  _multishell_armed=0
  _multishell_started=0
  # Inline, not in the background, for the same reasons as the zsh body.
  _multishell_command_started() {
    _multishell_ran=1
    _multishell_started=${EPOCHREALTIME:-$SECONDS}
    "$_multishell_bin" command-started --pid $$ >/dev/null 2>&1
  }
  _multishell_debug() {
    [ "$_multishell_armed" = 1 ] || return 0
    [ -n "${COMP_LINE-}" ] && return 0
    _multishell_armed=0
    case "$BASH_COMMAND" in _multishell_*) return 0 ;; esac
    _multishell_command_started
  }
  _multishell_precmd() {
    local e=$?
    if [ "$_multishell_ran" = 1 ]; then
      _multishell_ran=0
      # bash 3.2 has no EPOCHREALTIME; SECONDS is whole seconds, enough.
      local now=${EPOCHREALTIME:-$SECONDS}
      local d=$(( ${now%.*} - ${_multishell_started%.*} ))
      "$_multishell_bin" command-finished --exit "$e" --duration "$d" >/dev/null 2>&1
    fi
  }
  _multishell_arm() { _multishell_armed=1; }
  trap '_multishell_debug' DEBUG
  case "${PROMPT_COMMAND-}" in
    *_multishell_precmd*) ;;
    *)
      if [[ "$(declare -p PROMPT_COMMAND 2>/dev/null)" == "declare -a"* ]]; then
        PROMPT_COMMAND=(_multishell_precmd "${PROMPT_COMMAND[@]}" _multishell_arm)
      else
        PROMPT_COMMAND="_multishell_precmd${PROMPT_COMMAND:+; $PROMPT_COMMAND}; _multishell_arm"
      fi ;;
  esac
fi

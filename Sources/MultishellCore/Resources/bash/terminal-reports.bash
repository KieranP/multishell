# The marks init.bash writes in a Ghostty pane, which writes none for bash,
# so all three come from here and ride with the session's hooks. terminals.md.

# The terminal itself, as the DEBUG trap runs inside a redirected block's
# redirect; stdout where there is none. A failed `exec` ends a script's shell.
if [ "$_multishell_marks" = 1 ]; then
  if { true >/dev/tty; } 2>/dev/null; then exec 61>/dev/tty; else exec 61>&1; fi
fi

# Output start, as a command begins.
_multishell_output_mark() {
  if [ "$_multishell_marks" = 1 ]; then printf '\033]133;C\007' >&61; fi
}

# Raw, as zsh's; never from a subshell, whose output a substitution captures.
# A control character could end the sequence early, so it goes as unknown.
_multishell_report_directory() {
  [ "${BASH_SUBSHELL:-0}" = 0 ] || return 0
  _multishell_last_reported_directory=$PWD
  case "$PWD" in
    *[[:cntrl:]]*) printf '\033]7;\007' >&61 ;;
    *) printf '\033]7;kitty-shell-cwd://%s%s\007' "${HOSTNAME-}" "$PWD" >&61 ;;
  esac
}

# A deep directory as `…/` and its last three parts, as zsh's is. Untitled,
# a pane takes libghostty's title from each directory report: the raw path.
_multishell_directory_title() {
  # Its control characters dropped, as one could end the sequence early.
  local title="${PWD//[[:cntrl:]]/}" home="${HOME//[[:cntrl:]]/}" rest slashes
  # An empty HOME would match every path as `/*`.
  if [ -n "$home" ]; then
    case "$title" in
      "$home") title="~" ;;
      "$home"/*) title="~${title#"$home"}" ;;
    esac
  fi
  slashes="${title#/}"
  slashes="${slashes//[!\/]/}"
  if [ "${#slashes}" -ge 3 ]; then
    rest="${title%/*/*/*}"
    title="…${title#"$rest"}"
  fi
  printf '\033]2;%s\007' "$title" >&61
}

# Prompt start printed, input start on the end of PS1, which is why this
# runs last of all; see Docs/design/terminals.md.
_multishell_prompt_marks() {
  [ "$_multishell_marks" = 1 ] || return 0
  _multishell_report_directory
  if _multishell_has_feature title; then _multishell_directory_title; fi
  printf '\033]133;A;cl=line\007'
  [ -n "${PS1-}" ] || return 0
  case "$PS1" in
    *'133;B'*) ;;
    *) PS1="$PS1"'\[\e]133;B\a\]' ;;
  esac
}

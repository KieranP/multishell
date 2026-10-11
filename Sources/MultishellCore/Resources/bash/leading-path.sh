# A login profile's path_helper put /etc/paths ahead of the helper's directory,
# so `multishell` reached another build's; ours go back in front. terminals.md.
if [ -n "${MULTISHELL_LEADING_PATH-}" ] && [ -n "${PATH-}" ]; then
  _multishell_left="$PATH:"
  _multishell_rest=""
  while [ -n "$_multishell_left" ]; do
    _multishell_entry="${_multishell_left%%:*}"
    _multishell_left="${_multishell_left#*:}"
    case ":$MULTISHELL_LEADING_PATH:" in
      *":$_multishell_entry:"*) ;;
      *) _multishell_rest="${_multishell_rest:+$_multishell_rest:}$_multishell_entry" ;;
    esac
  done
  PATH="$MULTISHELL_LEADING_PATH${_multishell_rest:+:$_multishell_rest}"
  unset _multishell_left _multishell_rest _multishell_entry
fi

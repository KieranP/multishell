# /etc/zprofile's path_helper put /etc/paths ahead of the helper's directory, so
# `multishell` reached another build's; ours go first. terminals/sessions.md.
if [ -n "${MULTISHELL_LEADING_PATH-}" ]; then
  () {
    emulate -L zsh
    local -a lead=("${(@s.:.)MULTISHELL_LEADING_PATH}")
    path=("${lead[@]}" "${(@)path:|lead}")
  }
fi

# sudo and ssh wrapped where the user's shell-integration-features ask, as
# Ghostty's integration would; a function of the user's own is kept.

# sudo empties the environment, and root's terminfo has no xterm-ghostty. sudoedit
# refuses the flag, so an -e or --edit before the command goes on as typed.
if _multishell_has_feature sudo && [ -n "${TERMINFO-}" ] && ! declare -F sudo >/dev/null; then
  # `function`, as a user's `alias sudo='sudo '` would expand inside `sudo() {`.
  function sudo {
    local word next_is_value=0
    for word in ${1+"$@"}; do
      if [ "$next_is_value" = 1 ]; then next_is_value=0; continue; fi
      case "$word" in
        -e | --edit) command sudo ${1+"$@"}; return ;;
        -[CDgpRrTtUu] | --chdir | --chroot | --close-from | --command-timeout | --group | --host \
          | --other-user | --prompt | --role | --type | --user) next_is_value=1 ;;
        --) break ;;
        -* | *=*) ;;
        *) break ;;
      esac
    done
    command sudo --preserve-env=TERMINFO ${1+"$@"}
  }
fi

# A host without xterm-ghostty gets a TERM it knows. ssh-terminfo would install
# the entry, through a Ghostty CLI this bundle lacks; terminals.md.
if { _multishell_has_feature ssh-env || _multishell_has_feature ssh-terminfo; } \
  && ! declare -F ssh >/dev/null; then
  function ssh {
    if _multishell_has_feature ssh-env; then
      TERM=xterm-256color command ssh -o "SetEnv COLORTERM=truecolor" \
        -o "SendEnv TERM_PROGRAM TERM_PROGRAM_VERSION" ${1+"$@"}
    else
      TERM=xterm-256color command ssh ${1+"$@"}
    fi
  }
fi

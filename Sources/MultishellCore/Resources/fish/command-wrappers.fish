# sudo and ssh wrapped where the user's shell-integration-features ask, as
# Ghostty's integration would; a function of the user's own is kept.

# sudo empties the environment, and root's terminfo has no xterm-ghostty. sudoedit
# refuses the flag, so an -e or --edit before the command goes on as typed.
if _multishell_has_feature sudo; and test -n "$TERMINFO"; and not functions -q sudo
    function sudo --wraps sudo
        set -l next_is_value 0
        for word in $argv
            if test $next_is_value = 1
                set next_is_value 0
                continue
            end
            switch $word
                case -e --edit
                    command sudo $argv
                    return
                case -C -D -g -p -R -r -T -t -U -u --chdir --chroot --close-from \
                    --command-timeout --group --host --other-user --prompt --role --type --user
                    set next_is_value 1
                case --
                    break
                case '-*' '*=*'
                case '*'
                    break
            end
        end
        command sudo --preserve-env=TERMINFO $argv
    end
end

# A host without xterm-ghostty gets a TERM it knows. ssh-terminfo would install
# the entry, through a Ghostty CLI this bundle lacks; terminals.md.
if begin
        _multishell_has_feature ssh-env; or _multishell_has_feature ssh-terminfo
    end; and not functions -q ssh
    function ssh --wraps ssh
        set -l options
        _multishell_has_feature ssh-env
        and set options -o "SetEnv COLORTERM=truecolor" -o "SendEnv TERM_PROGRAM TERM_PROGRAM_VERSION"
        TERM=xterm-256color command ssh $options $argv
    end
end

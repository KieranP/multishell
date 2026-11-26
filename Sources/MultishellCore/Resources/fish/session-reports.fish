# The functions init.fish installs where the app gave the session its id:
# what it is told of each command. Docs/design/agents/reports-and-hooks.md.

# Inline, so a finished never passes its started; agents/reports-and-hooks.md.
# Checked per send: fish names a missing helper on stderr past any redirect.
function _multishell_send
    test -x $_multishell_bin; and $_multishell_bin $argv >/dev/null 2>&1
end

# `exec fish` puts a new fish in the pane that runs none of ours, so the plain
# forms start it as a tab's is; a redirection or another flag runs as typed.
function _multishell_reexec_if_replacing_itself
    set -l follows_a_refusal (set -q _multishell_exec_refused; and echo yes)
    set -e _multishell_exec_refused
    test "$argv[1]" = exec; or return
    set -l target $argv[2]
    contains -- "$target" '$SHELL' '${SHELL}'; and set target $SHELL
    string match -q --regex '(^|/)fish$' -- "$target"; or return
    for word in $argv[3..]
        contains -- $word -i -l -il -li --login --interactive; or return
    end
    string match -q '*/*' -- $target; or set target (command -s -- $target); or return
    test -x "$target"; or return
    # On a terminal fish refuses an exec with jobs running, then lets the next
    # line's through and hangs them up; ours keeps to that, or the one let through ran plain.
    if test -z "$follows_a_refusal"; and jobs -q; and isatty stdin
        set -g _multishell_exec_refused
        return
    end
    exec $target $argv[3..] -C "source "(string escape -- $_multishell_init_file)
end

# A shell exec'd to sit at its prompt keeps the pid and reports nothing, so a
# start sent for it held the pane Running until it closed. One given a command runs it.
function _multishell_execs_a_shell_at_its_prompt
    test "$argv[1]" = exec; or return 1
    set -l program $argv[2]
    contains -- "$program" '$SHELL' '${SHELL}'; and set program $SHELL
    string match -q --regex '(^|/)(zsh|bash|sh|dash|ksh|fish|tcsh|csh|nu)$' -- "$program"; or return 1
    set -l takes_value 0
    for word in $argv[3..]
        if test $takes_value = 1
            set takes_value 0
            continue
        end
        # fish's -C is a line run before its prompt, not a command in place of one.
        if string match -q --regex '^(-[^-]*c.*|--command(=.*)?|--commands)$' -- $word
            return 1
        else if contains -- $word -o +o -O +O -C --rcfile --init-file --init-command --emulate
            set takes_value 1
        else if not string match -q --regex '^[-+]' -- $word
            return 1
        end
    end
    return 0
end

function _multishell_preexec --on-event fish_preexec
    # The program being started, sent only for agents: the line's words as fish
    # splits them, past any prefix. Docs/design/agents/board-and-pane-rows.md.
    set -l words
    printf '%s' $argv[1] | read --null --tokenize --list --local words
    # A comment alone runs nothing, and its postexec would repeat the last status.
    set -g _multishell_ran (count $words)
    test $_multishell_ran -gt 0; or return
    _multishell_reexec_if_replacing_itself $words
    # The new shell never finishes this line, so it starts nothing.
    if _multishell_execs_a_shell_at_its_prompt $words
        set -g _multishell_ran 0
        return
    end
    set -l command_word ""
    for word in $words
        switch $word
            case '*=*' command env exec
                continue
        end
        set command_word (string replace --regex '.*/' '' -- $word)
        break
    end
    contains -- "$command_word" $_multishell_agents; or set command_word ""

    _multishell_send command-started --pid $fish_pid --command "$command_word"
end

function _multishell_postexec --on-event fish_postexec
    set -l exit_code $status
    test "$_multishell_ran" -gt 0 2>/dev/null; or return
    set -g _multishell_ran 0
    # The helper takes seconds, and fish counts whole milliseconds.
    set -l ms (string pad --char 0 --width 4 -- $CMD_DURATION)
    set -l duration (string sub --end -3 -- $ms).(string sub --start -3 -- $ms)

    _multishell_send command-finished --exit $exit_code --duration $duration
end

# Idle on the way out, as zsh ends: `exit 3` reports a failure first.
function _multishell_exit --on-event fish_exit
    _multishell_send state idle --shell true
end

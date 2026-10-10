# Multishell's fish integration, run through `-C` once the user's config has.
# Two halves: what a Ghostty pane is told, and what the app is told.

# fish 4 writes its own prompt marks, directory and title; terminals.md.
if status is-interactive; and test "$TERM_PROGRAM" = ghostty
    # Ghostty exports the user's shell-integration-features, `cursor:blink` and all.
    function _multishell_has_feature
        string match -q -- "*,$argv[1],*" ",$GHOSTTY_SHELL_FEATURES,"
        or string match -q -- "*,$argv[1]:*" ",$GHOSTTY_SHELL_FEATURES,"
    end

    # include terminal-reports.fish
    # include command-wrappers.fish
end

if status is-interactive; and test -n "$MULTISHELL_SESSION"; and test -x "__MULTISHELL_HELPER__"
    set -g _multishell_bin "__MULTISHELL_HELPER__"
    set -g _multishell_agents __MULTISHELL_AGENTS__

    # include session-reports.fish
end

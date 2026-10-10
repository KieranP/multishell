# What init.fish adds in a Ghostty pane to the marks fish writes itself: the
# cursor's shape. Why: Docs/design/terminals.md.

# A bar to type in, the configured shape back for a program. fish's own vi-mode
# handler draws every shape itself, so ours stands back.
if _multishell_has_feature cursor
    function _multishell_prompt_cursor --on-event fish_prompt
        functions -q fish_vi_cursor_handle; and return
        set -l shape 5
        _multishell_has_feature cursor:steady; and set shape 6
        printf '\e[%s q' $shape
    end

    function _multishell_program_cursor --on-event fish_preexec
        functions -q fish_vi_cursor_handle; or printf '\e[0 q'
    end
end

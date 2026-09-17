#!/bin/sh
# PostToolUse hook on Write|Edit, fed the tool call as JSON on stdin: prettier
# on a Markdown file the agent wrote, so `make format` finds nothing to do.
file=$(jq -r '.tool_input.file_path // empty')

case "$file" in
  "$CLAUDE_PROJECT_DIR"/*.md) ;;
  *) exit 0 ;;
esac

# Prettier refuses a symlink; CLAUDE.md is formatted through AGENTS.md.
[ -L "$file" ] && exit 0
command -v prettier >/dev/null || exit 0

prettier --write --log-level warn "$file"

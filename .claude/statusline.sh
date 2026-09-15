#!/bin/sh
input=$(cat)

cwd=$(echo "$input" | jq -r '.cwd')
model=$(echo "$input" | jq -r '.model.display_name')

# Get git branch: prefer worktree.branch from JSON, fall back to git rev-parse
branch=$(echo "$input" | jq -r '.worktree.branch // empty')
[ -z "$branch" ] && branch=$(git -C "$cwd" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)

# Get effort level from settings
effort=$(jq -r '.effortLevel // empty' ~/.claude/settings.json 2>/dev/null)

# Build output
out=" $cwd"
[ -n "$branch" ] && out="$out |  $branch"
out="$out | 󰧑 $model"
[ -n "$effort" ] && out="$out [$effort]"

# Append context window usage if available
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
if [ -n "$used_pct" ] && [ -n "$ctx_size" ]; then
  used_k=$(awk "BEGIN { printf \"%.0f\", ($used_pct / 100) * $ctx_size / 1000 }")
  total_k=$(awk "BEGIN { printf \"%.0f\", $ctx_size / 1000 }")
  out="$out | 󰍛 ${used_k}k/${total_k}k"
fi

# Format seconds into a compact countdown string (e.g. "2d03h", "1h23m", or "45m")
format_countdown() {
  secs=$1
  if [ "$secs" -le 0 ]; then
    echo "now"
  elif [ "$secs" -ge 86400 ]; then
    d=$(( secs / 86400 ))
    h=$(( (secs % 86400) / 3600 ))
    printf '%dd%02dh' "$d" "$h"
  elif [ "$secs" -ge 3600 ]; then
    h=$(( secs / 3600 ))
    m=$(( (secs % 3600) / 60 ))
    printf '%dh%02dm' "$h" "$m"
  else
    m=$(( secs / 60 ))
    printf '%dm' "$m"
  fi
}

# Mark a rate limit percentage: warning triangle from 90%, red alert at 100%
LIMIT_ICON=$(printf '\357\201\261')
limit_marker() {
  case "$(awk -v p="$1" 'BEGIN { print (p >= 100) ? 2 : ((p >= 90) ? 1 : 0) }')" in
    2) printf ' \033[1;31m%s\033[0m' "$LIMIT_ICON" ;;
    1) printf ' \033[1;33m%s\033[0m' "$LIMIT_ICON" ;;
  esac
}

now=$(date +%s)

# Append hourly (5-hour) rate limit usage and reset countdown if available
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_resets=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
if [ -n "$five_pct" ]; then
  five_str="󱑔 5h: $(printf '%.0f' "$five_pct")%$(limit_marker "$five_pct")"
  if [ -n "$five_resets" ]; then
    five_remaining=$(( five_resets - now ))
    five_str="$five_str ($(format_countdown "$five_remaining"))"
  fi
  out="$out | $five_str"
fi

# Append weekly (7-day) rate limit usage and reset countdown if available
week_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
week_resets=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')
if [ -n "$week_pct" ]; then
  week_str="󰃶 7d: $(printf '%.0f' "$week_pct")%$(limit_marker "$week_pct")"
  if [ -n "$week_resets" ]; then
    week_remaining=$(( week_resets - now ))
    week_str="$week_str ($(format_countdown "$week_remaining"))"
  fi
  out="$out | $week_str"
fi

echo "$out"

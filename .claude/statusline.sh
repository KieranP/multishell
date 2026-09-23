#!/bin/bash
# Character counts and substrings below assume UTF-8
export LC_ALL=C.UTF-8
input=$(cat)

cwd=$(echo "$input" | jq -r '.cwd')
display_cwd=$cwd
home=${HOME%/}
if [ -n "$home" ]; then
  case "$cwd" in
    "$home" | "$home"/*) display_cwd="~${cwd#"$home"}" ;;
  esac
fi
model=$(echo "$input" | jq -r '.model.display_name')

# Get git branch: prefer worktree.branch from JSON, fall back to git rev-parse
branch=$(echo "$input" | jq -r '.worktree.branch // empty')
[ -z "$branch" ] && branch=$(git -C "$cwd" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)

# Session effort changes with /effort; settings.json holds only the default
effort=$(echo "$input" | jq -r '.effort.level // empty')
[ -z "$effort" ] && effort=$(jq -r '.effortLevel // empty' ~/.claude/settings.json 2>/dev/null)

model_str="󰧑 $model"
[ -n "$effort" ] && model_str="$model_str [$effort]"

# Takes the path and branch to show, so either can be shortened to fit
build_left() {
  left=" $1"
  [ -n "$2" ] && left="$left |  $2"
}

# Fish-style: every directory but the last cut to one letter (two for dotdirs).
# Bash substrings count characters; awk's substr cuts UTF-8 mid-byte.
abbreviate_path() {
  local dir=${1%/*} last=${1##*/} out="" part parts
  if [ "$dir" = "$1" ] || [ -z "$last" ]; then
    echo "$1"
    return
  fi
  IFS=/ read -ra parts <<< "$dir"
  for part in "${parts[@]}"; do
    case $part in
      .*) out="$out${part:0:2}/" ;;
      *) out="$out${part:0:1}/" ;;
    esac
  done
  echo "$out$last"
}

ESC=$(printf '\033')
display_width() {
  printf '%s' "$1" | sed "s/$ESC\[[0-9;]*m//g" | wc -m
}

out=""

# Append context window usage if available
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
if [ -n "$used_pct" ] && [ -n "$ctx_size" ]; then
  used_k=$(awk "BEGIN { printf \"%.0f\", ($used_pct / 100) * $ctx_size / 1000 }")
  total_k=$(awk "BEGIN { printf \"%.0f\", $ctx_size / 1000 }")
  out=" | 󰍛 ${used_k}k/${total_k}k"
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

right=${out# | }

# Claude Code sets COLUMNS for the statusline command. The margin allows for
# its padding; 4 is a guess, raise it if the line end still clips.
STATUS_MARGIN=4
max_width=$(( ${COLUMNS:-0} - STATUS_MARGIN ))

too_wide() {
  [ "${COLUMNS:-0}" -gt 0 ] && [ "$(display_width "$1")" -gt "$max_width" ]
}

short_cwd=$(abbreviate_path "$display_cwd")
rest="$model_str${right:+ | $right}"

build_left "$display_cwd" "$branch"
line="$left | $rest"
if too_wide "$line"; then
  build_left "$short_cwd" "$branch"
  line="$left | $rest"
fi
if too_wide "$line"; then
  if too_wide "$left"; then
    build_left "$short_cwd" ""
    room=$(( max_width - $(display_width "$left | x ") ))
    [ "$room" -gt 1 ] && build_left "$short_cwd" "${branch:0:room-1}…"
  fi
  line="$left
$rest"
fi

printf '%s\n' "$line"

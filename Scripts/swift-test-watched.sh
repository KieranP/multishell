#!/bin/bash
# Runs `swift test`. Where it prints nothing for TEST_QUIET_LIMIT seconds, names what
# is running, samples the test processes into TEST_DIAGNOSTICS and fails.
set -uo pipefail

quiet_limit="${TEST_QUIET_LIMIT:-180}"
diagnostics="${TEST_DIAGNOSTICS:-$(mktemp -d)}"
mkdir -p "$diagnostics"
events="$diagnostics/events.jsonl"
console="$diagnostics/console.log"
rm -f "$events" "$console"

# Quiet is read off the console: CI's runner wrote no event stream at all.
swift test "$@" --event-stream-output-path "$events" --event-stream-version 0 \
  > >(tee -a "$console") 2>&1 &
tests=$!

# Ended tests drop out; a parameterised test's cases end before it does.
still_running() {
  jq -Rrn '
    reduce (inputs | fromjson? | select(.kind == "event") | .payload) as $event ({};
      if $event.kind == "testStarted" then .[$event.testID] = $event.instant.since1970
      elif $event.kind == "testEnded" then del(.[$event.testID])
      else . end)
    | to_entries | sort_by(.value) | .[] | select(.key | contains("(")) | .key
  ' "$events"
}

# Its own descendants only: a pattern would reach another worktree's run.
descendants() {
  local child
  for child in $(pgrep -P "$1"); do
    echo "$child"
    descendants "$child"
  done
}

last_size=-1
quiet=0
while kill -0 "$tests" 2>/dev/null; do
  sleep 5
  size=$(stat -f %z "$console" 2>/dev/null || echo 0)
  if [ "$size" = "$last_size" ]; then
    quiet=$((quiet + 5))
  else
    quiet=0
    last_size=$size
  fi
  [ "$quiet" -ge "$quiet_limit" ] || continue

  echo "error: no output for ${quiet_limit}s; these were still running:" >&2
  [ -s "$events" ] && still_running | sed 's/^/  /' >&2
  stuck=$(descendants "$tests")
  echo "and these processes were under the run:" >&2
  for pid in $stuck; do
    ps -o pid=,ppid=,stat=,etime=,pending=,blocked=,command= -p "$pid" | cut -c1-200 >&2
  done
  for pid in $stuck; do
    case "$(ps -o comm= -p "$pid")" in
      *swiftpm-testing-helper | *xctest)
        sample "$pid" 10 -file "$diagnostics/sample-$pid.txt" > /dev/null 2>&1
        echo "  sampled $pid into $diagnostics/sample-$pid.txt" >&2
        ;;
    esac
  done
  kill -KILL $stuck "$tests" 2>/dev/null
  wait "$tests"
  exit 1
done
wait "$tests"

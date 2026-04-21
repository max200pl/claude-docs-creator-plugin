#!/bin/bash
# PreToolUse(WebSearch|WebFetch): suggest wrapping web lookups in /research
# so findings persist as a structured report in docs/research-<slug>.md.
# Non-blocking — just injects additionalContext into Claude's model context.
set -u

COUNTER=/tmp/claude-docs-creator-web-calls-$PPID

# Increment session-scoped counter.
count=$(cat "$COUNTER" 2>/dev/null || echo 0)
count=$((count + 1))
echo "$count" > "$COUNTER"

MSG1='Web research tip — first web lookup this session. If this turns into substantive research (best practices, comparisons, deep dives), consider wrapping the work in `/research <topic>` so findings persist as a structured report in `docs/research-<slug>.md` with real sources, a gaps table, and recommendations. One-off lookups do not need it.'

MSG3='Web research tip — 3 web lookups this session. At this density the work is no longer a quick reference, it is research. Strongly consider pausing and running `/research <topic>` to consolidate findings into a report under `docs/`. The skill reads existing reports, so re-running later extends rather than duplicates.'

# Fire suggestion on 1st call (nudge early) and 3rd call (pattern detected).
# Silent on call #2 and #4+ to avoid spamming.
msg=""
[ "$count" -eq 1 ] && msg="$MSG1"
[ "$count" -eq 3 ] && msg="$MSG3"
[ -z "$msg" ] && exit 0

jq -n --arg m "$msg" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    additionalContext: $m
  }
}'
exit 0

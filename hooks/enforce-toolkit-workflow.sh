#!/usr/bin/env bash
# PreToolUse hook: when editing .claude/** or CLAUDE.md, remind to use toolkit skills.
# Outputs additionalContext via hookSpecificOutput — does not block, just nudges.

set -u

payload="$(cat)"
file_path="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty')"

if [[ -z "$file_path" ]]; then
  exit 0
fi

# Match .claude/ anywhere in the path, or CLAUDE.md basename, or nested CLAUDE.md
if [[ "$file_path" == *"/.claude/"* ]] \
   || [[ "$(basename "$file_path")" == "CLAUDE.md" ]] \
   || [[ "$(basename "$file_path")" == "CLAUDE.local.md" ]]; then

  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      additionalContext: "Editing a toolkit-governed file (.claude/** or CLAUDE.md). Confirm you are inside a toolkit skill (/create-docs, /update-docs, /init-project, /create-mermaid, etc.) — hand-edits are reserved for typo fixes, validate-fix follow-ups, rollbacks, or filling skill-scaffolded placeholders. See rules/toolkit-workflow.md."
    }
  }'
fi

exit 0

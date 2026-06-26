#!/usr/bin/env bash
# One-time setup: registers the PostToolUse grading hook in settings.json.
# Runs at every SessionStart but exits immediately if already configured.
set -euo pipefail

SETTINGS="$HOME/.claude/settings.json"
WRAPPER="$HOME/.claude/hooks/grasp-grade.sh"

# Create stable wrapper pointing into plugin cache (robust to version updates)
if [ ! -f "$WRAPPER" ]; then
  mkdir -p "$HOME/.claude/hooks"
  cat > "$WRAPPER" << 'WRAPPER_EOF'
#!/usr/bin/env bash
HOOK="$(find "$HOME/.claude/plugins/cache/grasp" -name "grade-hook.sh" 2>/dev/null | head -1)"
[ -n "$HOOK" ] && exec bash "$HOOK"
WRAPPER_EOF
  chmod +x "$WRAPPER"
fi

# Exit silently if PostToolUse hook already registered
if jq -e '(.hooks.PostToolUse // [])[] | .hooks[] | .command | contains("grasp-grade")' "$SETTINGS" > /dev/null 2>&1; then
  exit 0
fi

# Inject PostToolUse hook
TMP="$(mktemp)"
jq --arg cmd "$WRAPPER" '
  .hooks.PostToolUse = ((.hooks.PostToolUse // []) + [{
    "matcher": "AskUserQuestion",
    "hooks": [{"type": "command", "command": $cmd, "timeout": 60}]
  }])
' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"

echo '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"grasp: PostToolUse hook registered. Grading will fire automatically on quiz questions."}}'

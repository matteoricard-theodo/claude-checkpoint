#!/usr/bin/env bash
# PostToolUse hook for AskUserQuestion. Deterministic dispatch: only grades
# quiz questions tagged metadata.source == "grasp". Everything else
# (any other AskUserQuestion call) passes through silently.
#
# Matches questions to criteria by ARRAY INDEX, not by question text. The
# sidecar file is a plain ordered JSON array of criteria strings, written in
# the same order as the questions about to be asked. Index matching avoids
# relying on two independently-typed copies of the question text staying
# byte-identical (that broke on an accent mismatch in an earlier version).
set -euo pipefail

CRITERIA_FILE="$HOME/.claude/.grasp-criteria.json"

INPUT="$(cat)"

SOURCE="$(echo "$INPUT" | jq -r '.tool_input.metadata.source // empty')"
if [ "$SOURCE" != "grasp" ]; then
  exit 0
fi

if [ ! -f "$CRITERIA_FILE" ]; then
  exit 0
fi

CRITERIA="$(cat "$CRITERIA_FILE")"
N="$(echo "$INPUT" | jq '.tool_input.questions | length')"

VERDICTS=""

for i in $(seq 0 $((N - 1))); do
  QTEXT="$(echo "$INPUT" | jq -r --argjson i "$i" '.tool_input.questions[$i].question')"
  ANSWER="$(echo "$INPUT" | jq -r --arg q "$QTEXT" '.tool_response.answers[$q] // empty')"
  CRITERION="$(echo "$CRITERIA" | jq -r --argjson i "$i" '.[$i] // empty')"

  if [ -z "$ANSWER" ] || [ -z "$CRITERION" ]; then
    continue
  fi

  PROMPT="Grade this developer's answer. Question: ${QTEXT}
What a correct answer must contain: ${CRITERION}
Developer's answer: ${ANSWER}
Reply with exactly: verdict (correct/partial/wrong) then a dash then a one-sentence reason in French. No other text."

  GRADE="$(claude -p "$PROMPT" --model haiku 2>/dev/null || echo "wrong - grading subagent failed")"

  VERDICTS="${VERDICTS}- Q: ${QTEXT}
  R: ${ANSWER}
  -> ${GRADE}
"
done

rm -f "$CRITERIA_FILE"

if [ -z "$VERDICTS" ]; then
  exit 0
fi

CONTEXT="Quiz grading results (graded by Haiku subagent, deterministic dispatch, zero main-thread tokens spent on routing):
${VERDICTS}
Relay these verdicts to the developer: explain each grade, correct gaps, give final overall verdict on whether understanding is solid enough to move on."

jq -n --arg ctx "$CONTEXT" '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":$ctx}}'

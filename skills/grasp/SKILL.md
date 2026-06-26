---
name: grasp
description: >
  Verifies that a developer actually understood what Claude just implemented,
  without blocking delivery. Modes: quiz (recap + questions after the fact,
  default — multiple-choice-ish with an "I don't know" option), quiz forced
  (same but with no real choices, forcing the developer to type their own
  explanation), or inline (pause at each major step, developer must explain
  before continuing). Use when user says "check my understanding", "quiz me
  on this", "explain what was just done", or invokes
  /grasp [quiz|quiz forced|inline].
---

Role: technical mentor. Goal = developer understands EVERY step of what Claude just shipped, without killing delivery speed. Not a simple "did you get it?" — targeted questions that force explaining the WHY, not just the WHAT.

Respond in whatever language the conversation is using (recap, questions, feedback) — this file is English, the interaction doesn't have to be.

## Default mode: `quiz` (post-implementation)

Triggered by `/grasp` or `/grasp quiz`. Two variants:

- **`quiz`** (plain, default): options include 1-2 short neutral/plausible-but-partial picks plus "Je ne sais pas"/"I don't know" — quick recall is possible, but "Other" stays the expected default path.
- **`quiz forced`**: forces explanation in the developer's own words. Options are three honest non-answer paths (room for up to 4, so no need to squeeze into 2): (1) "Je ne sais pas"/"I don't know", (2) "Je remets en question ce choix"/"I want to challenge this choice", (3) "J'ai une question dessus"/"I have a question about this". None of these reveal or resemble a correct technical answer — there is nothing to lazily pick that counts as "passing". The only way to actually answer is "Other".

  Handling each non-answer pick (override the grading hook's verdict for these — don't relay a "wrong"/"correct" grade, the hook doesn't know these are special):
  - **"Je ne sais pas"**: teach the answer directly, no judgment (see step 7).
  - **"Je remets en question ce choix"**: this isn't a comprehension gap, it's a technical disagreement — drop the quiz framing and have the actual debate. Justify the decision with real reasoning, or concede the developer has a point and say so.
  - **"J'ai une question dessus"**: answer their question first, directly. Then optionally re-offer the original question once they've got what they needed.

  Use `quiz forced` when the user explicitly asks for the stricter variant, or when previous quiz answers show the developer is pattern-matching options instead of reasoning.

1. **Scope it**: if in a git repo, `git diff` / `git diff --staged` on recent changes. Otherwise reconstruct from the conversation what was just done.
2. **Short recap**: bullet list, one point per key decision or step — not per file. E.g. "Added retry with backoff on the API call" rather than "Modified api_client.py".
3. **3 to 5 targeted questions**, never yes/no. For each, draft a 1-2 sentence **grading criterion**: what a correct answer must contain. Aim for:
   - The WHY behind a choice (why this approach over the obvious alternative)
   - A consequence/tradeoff (what breaks if you remove X, what happens in case Y)
   - A point developers commonly confuse about this exact pattern
4. **Write the criteria sidecar file** at `~/.claude/.grasp-criteria.json`, a flat JSON **array** of criterion strings, in the exact same order as the questions you're about to ask: `["<criterion for Q1>", "<criterion for Q2>", ...]`. Matching is by array position, not by question text — don't key it by question text, that broke on a single accent typo before. This file is consumed and deleted by a hook, so always overwrite it fresh per quiz.
5. **Ask via the AskUserQuestion tool**, not plain chat text — one question per item (up to 4 per call, split into multiple calls if you have 5, same call order as the sidecar array), `metadata.source` set to `"grasp"` on every call (this is what tells the grading hook to engage — without it, the hook ignores the call). This is NOT meant to feel like a forced multiple-choice quiz: **the default expected path is "Other" — the developer just types their own explanation.** Options are an optional convenience for quick recall-type questions where a fast pick makes sense, not a mandatory decoy-trap mechanic. The tool requires 2-4 options regardless — when the question genuinely needs an open explanation rather than a pick, keep those options minimal/neutral (e.g. a short plausible-but-partial phrasing) rather than crafting elaborate decoys, since "Other" is where the real answer is expected to come from anyway. **Always include one option that is exactly "Je ne sais pas" / "I don't know"** (match the conversation's language) — a clean honest opt-out so the developer never has to fake-pick a decoy or type something just to move on.
6. **A PostToolUse hook grades automatically** (deterministic dispatch, zero main-thread tokens spent on routing): it reads the sidecar criteria + the developer's answers, calls a headless Haiku grading pass per question, and injects the verdicts back as context. You do not need to call the Agent tool yourself for grading — wait for that injected context.
7. **Relay the verdicts**: present each grade to the developer — say why, correct without condescension, give the missing intuition. If a verdict looks off given context only you have from the conversation, override it and say so. If the answer was "Je ne sais pas"/"I don't know", skip the grading tone entirely — just teach the answer directly, no "wrong" framing for an honest opt-out.
8. **Final verdict**: understanding is good enough to move on, or flag point(s) to dig into before continuing. If a gap keeps recurring, suggest a resource or a short reframe — not a lecture.

Don't give the answer away inside the question itself or its decoy options. Don't grade the person — judge understanding of the subject.

## `inline` mode

Triggered by `/grasp inline`. Stays active for the current session (or until "stop grasp" / "normal mode").

Before executing a new significant group of actions (e.g. before moving to a new file, a new function, a new architectural decision), Claude:
1. Pauses, explains what's about to be done and why (2-3 sentences max, not an essay).
2. Asks the developer to paraphrase in their own words before continuing ("tell me what you're taking away before I continue").
3. If the paraphrase is correct → continue. If wrong/vague → correct it, then ask for a short re-paraphrase before proceeding.

This mode slows delivery down — that's the accepted tradeoff. Don't activate it without an explicit request.

## Auto-clarity

For both modes: if a developer's answer reveals a real gap (not a minor detail), take the time to explain properly even if it breaks the terse format — understanding beats compression.

## Setup dependency

The `quiz` mode's auto-grading runs via a PostToolUse hook on AskUserQuestion, bundled with this plugin. Without the hook registered, the AskUserQuestion call still works but no grading context comes back — fall back to grading the answers yourself in that case.

## Boundaries

This skill doesn't rewrite code, doesn't approve a PR, doesn't replace a human review. It checks understanding, period.

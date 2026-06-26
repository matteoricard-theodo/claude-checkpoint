# grasp

Claude Code plugin that ensures developers understand each implementation step, without blocking delivery.

## Install

```bash
claude plugin marketplace add matteoricard-theodo/claude-grasp
claude plugin install grasp
```

## Usage

After Claude implements something, run:

```
/grasp                 # quiz mode (default): recap + targeted questions with options
/grasp quiz forced     # forced mode: no answer options, must type explanation
/grasp inline          # inline mode: pause before each step, explain before continuing
```

## How it works

- Claude scopes recent changes (git diff or conversation)
- Asks 3-5 targeted questions via structured cards (AskUserQuestion)
- A PostToolUse hook auto-grades each answer via headless Haiku, zero main-thread token cost
- Claude relays verdicts, corrects gaps, gives a final "move on / dig deeper" verdict

## Modes

| Mode | When to use |
|------|-------------|
| `quiz` | Default. Options + free text. Fast recall or typed explanation. |
| `quiz forced` | Developer is picking options without reasoning. Forces typed explanation only. |
| `inline` | High-stakes implementation. Pauses before each step. Slower but thorough. |

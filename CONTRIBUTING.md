# Contributing

Thanks for helping improve Claude Code Profiles Bootstrap! This guide keeps changes consistent and easy to review.

## Getting Started
- Clone and install: `bash install-claude-profiles.sh --dry-run` to preview, then run without `--dry-run`.
- Diagnostics: `bash install-claude-profiles.sh --doctor` to verify environment.
- Switch providers quickly: `cc-use anthropic|zai -- /status`.

## Code Changes
- Keep installer and `extras/` snippets in sync (env unsets, usage text, URLs).
- Shell style: `bash`, `set -euo pipefail`, quote vars, avoid `eval`, check exit codes.
- No secrets in repo. Use env, `pass`, or Keychain in examples.
- Update docs when behavior or flags change (README, AGENTS.md).

## Commit & PR
- Use concise, imperative commit subjects (≤72 chars).
- Reference issues (e.g., `Fixes #123`).
- PRs: describe motivation, changes, testing steps, and screenshots if UX.
- Ensure `--doctor` passes and examples run.

## Tests & Verification
- Prefer targeted manual checks:
  - `cc-use anthropic -- /status` and `cc-use zai -- /status`
  - direnv template works after `direnv allow`
- If adding Python or scripts, add lightweight tests where reasonable.

## Reporting Issues
- Include OS, shell, Node/npm versions, installer flags used, and logs.

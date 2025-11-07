# Repository Guidelines

This guide helps contributors work effectively in this repository.

## Project Structure & Module Organization
- `src/` — main source (agents, prompts, utilities). Example: `src/cli/`, `src/core/`.
- `profiles/` — profile definitions and assets used by agents.
- `tests/` — automated tests mirroring `src/` structure.
- `scripts/` — helper scripts for local dev and CI.
- `docs/` — user and developer documentation.

## Build, Test, and Development Commands
- `make setup` — install dependencies and pre-commit hooks.
- `make dev` — run the local development entrypoint (watch mode when supported).
- `make test` — run the test suite with coverage summary.
- `make lint` — run linters/formatters (fails on style issues).
- `make build` — produce distributable artifacts (if applicable).
- `make fmt` — auto-format codebase.

Examples:
- Run a focused test: `pytest tests/cli/test_profile_load.py -q`.
- Lint only changed files: `ruff check .` and `pre-commit run -a`.

## Coding Style & Naming Conventions
- Bash scripts: target POSIX where possible for helpers; use `bash` with `set -euo pipefail` for installers.
- Shell style: quote variables, prefer long flags, avoid `eval`, and check exit codes.
- Python (if added): 3.10+, Black (88), Ruff, isort; 4-space indents; `snake_case` for functions/vars, `PascalCase` for classes.
- Naming: scripts in `extras/` use `kebab-case.sh`; functions use `lower_snake_case`.
- Docs: keep README and inline comments concise and task-focused.

## Testing Guidelines
- Framework: `pytest` with `pytest-cov` for coverage.
- Test layout mirrors `src/` (e.g., `src/core/x.py` -> `tests/core/test_x.py`).
- Name tests `test_*.py`; use descriptive test names.
- Run all tests: `make test`; single file: `pytest tests/core/test_x.py -q`.
- Aim for ≥80% coverage on changed code; include edge cases and error paths.

## Commit & Pull Request Guidelines
- Commit style: concise imperative subject (≤72 chars), optional body with rationale.
- Reference issues in body (e.g., `Fixes #123`).
- PRs must include: clear description, linked issues, test updates, and screenshots for UX changes.
- Ensure `make lint` and `make test` pass before requesting review.

## Security & Configuration Tips
- Never commit secrets; use environment variables and `.env.example` for templates.
- Validate profile inputs; treat external content as untrusted.
- Prefer deterministic builds; pin critical dependencies where possible.

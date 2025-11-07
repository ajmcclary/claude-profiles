# Claude Code Profiles Bootstrap

![Shell](https://img.shields.io/badge/shell-bash-4EAA25?logo=gnu-bash&logoColor=white)
![OS](https://img.shields.io/badge/os-macOS%20%7C%20Linux-blue)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

This bundle installs **Claude Code** (Anthropic) and sets up two profiles so you can switch between **Anthropic** and **Z.ai GLM Coding Plan** in one command.

## Files
- `install-claude-profiles.sh` — idempotent installer (Linux/macOS). Sets up:
  - Node via `nvm` (if needed)
  - Claude Code CLI
  - Two profiles: `anthropic` and `zai` (no secrets stored on disk)
  - Shell helpers: `cc-profile`, `cc-use`, `claude-anthropic`, `claude-glm`
  - Optional direnv template (`--with-direnv`)
- `examples/.envrc.claude` — a per-repo direnv template
- `extras/cc-use-only.sh` — a minimal one-file toggle (no install; source it to use)
- `extras/rc-snippet.sh` — the shell helpers as a standalone snippet

## Quick start
```bash
bash install-claude-profiles.sh
# or include direnv scaffolding
bash install-claude-profiles.sh --with-direnv
```

Open a new shell or `source ~/.zshrc` (or `~/.bashrc`).

## Demo
Animated walkthrough of switching and one‑off usage:

![Demo](docs/demo-switch.gif)

## Installer flags
```bash
# show help and version
bash install-claude-profiles.sh --help
bash install-claude-profiles.sh --version

# plan actions without changing your system
bash install-claude-profiles.sh --dry-run

# diagnostics and cleanup
bash install-claude-profiles.sh --doctor
bash install-claude-profiles.sh --uninstall
```

### Usage
- Persist default provider:
  ```bash
  cc-profile anthropic    # or: cc-profile zai
  ```
  Shorthand examples:
  ```bash
  # Switch default to GLM then start Claude
  cc-profile zai && claude

  # Switch default to Anthropic then start Claude
  cc-profile anthropic && claude
  ```
- One-off without editing files:
  ```bash
  cc-use anthropic -- /status
  cc-use zai -- /status
  ```
- Convenience:
  ```bash
  claude-anthropic
  claude-glm
  ```

Shorthand equivalents:
```bash
# One-off GLM without changing default
cc-use zai -- /status

# One-off Anthropic without changing default
cc-use anthropic -- /status
```

### Secrets
No API keys are stored in profile files. Keys are read from environment variables or helper scripts:
- Anthropic: `ANTHROPIC_API_KEY`
- Z.ai: `ZAI_API_KEY` (sent as `Authorization: Bearer` via `ANTHROPIC_AUTH_TOKEN`)

You can wire them to a password store (e.g., `pass`) or macOS Keychain.

### Uninstall
- Remove the shell block between `# >>> claude-profiles >>>` and `# <<< claude-profiles <<<` from your shell rc.
- Delete `~/.claude/profiles/*` and `~/.claude/settings.json` if desired (keep backups created by the installer).

## Troubleshooting
- npm install fails: ensure network access and try `npm cache verify` then rerun. If using a proxy, configure `npm config set proxy`/`https-proxy`.
- `claude` not found after install: open a new shell or `source ~/.zshrc` (or `~/.bashrc`). If you use `nvm`, confirm your rc loads `nvm.sh`.
- Permission denied for helpers: run `chmod +x ~/.claude/bin/*`.
- Updating shell helpers: remove the block between markers in your rc and rerun the installer to refresh to the latest snippet.
- direnv not active: install it (`brew install direnv` or your distro’s package) and ensure your shell rc contains the direnv hook.

## Project description
Bootstrap Claude Code with seamless provider switching. One command installs the CLI, creates secure Anthropic and GLM (Z.ai) profiles, and adds shell helpers: `cc-profile`, `cc-use`, `claude-anthropic`, `claude-glm`. No secrets on disk—env, pass, or Keychain. Optional direnv template, doctor/uninstall, and dry-run for safety.

## License
Released under the MIT License. See `LICENSE` for details.

## Contributing
- Issues and feature requests are welcome via GitHub Issues.
- For changes, open a PR with a clear description, linked issues, and before/after notes.
- Run locally: `bash install-claude-profiles.sh --dry-run` and `--doctor` for checks.
- Ensure helpers and docs stay in sync (installer snippet and `extras/`).

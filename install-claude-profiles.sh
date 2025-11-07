#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
#  Claude Code bootstrap: profiles + easy switching + optional direnv template
#  - Linux/macOS only
#  - Never stores API keys on disk; uses env or helpers
#  - Safe to run multiple times
# ==============================================================================

# -------------------------
#        Constants
# -------------------------
SCRIPT_VERSION="1.1.0"
NVM_VERSION="${NVM_VERSION:-v0.40.3}"
NODE_MIN_VERSION="${NODE_MIN_VERSION:-18}"
NODE_INSTALL_VERSION="${NODE_INSTALL_VERSION:-22}"

CLAUDE_NPM_PKG="@anthropic-ai/claude-code"
ZAI_BASE_URL="https://api.z.ai/api/anthropic"

WITH_DIRENV="0"
DRY_RUN="0"
DO_UNINSTALL="0"
DO_DOCTOR="0"
QUIET="0"
VERBOSE="0"

print_help(){
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --with-direnv      Include direnv hook and template
  --dry-run          Print planned actions without changing the system
  --doctor           Run diagnostics and exit
  --uninstall        Remove RC block, profiles, helpers, and settings link
  --quiet            Reduce output
  --verbose          Increase output
  --version          Print script version
  -h, --help         Show this help
EOF
}

for arg in "$@"; do
  case "$arg" in
    --with-direnv) WITH_DIRENV="1" ;;
    --dry-run) DRY_RUN="1" ;;
    --doctor) DO_DOCTOR="1" ;;
    --uninstall) DO_UNINSTALL="1" ;;
    --quiet) QUIET="1" ;;
    --verbose) VERBOSE="1" ;;
    --version) echo "$SCRIPT_VERSION"; exit 0 ;;
    -h|--help) print_help; exit 0 ;;
    *) ;;
  esac
done

SCRIPT_OS="$(uname -s)"
HOME_DIR="${HOME}"
CLAUDE_DIR="${HOME_DIR}/.claude"
CLAUDE_BIN_DIR="${CLAUDE_DIR}/bin"
PROFILES_DIR="${CLAUDE_DIR}/profiles"
SETTINGS_SYMLINK="${CLAUDE_DIR}/settings.json"
ONBOARD_FILE="${HOME_DIR}/.claude.json"

# -------------------------
#        Logging
# -------------------------
log_i(){ [ "$QUIET" = "1" ] && return 0; printf "🔹 %s\n" "$*"; }
log_ok(){ [ "$QUIET" = "1" ] && return 0; printf "✅ %s\n" "$*"; }
log_err(){ printf "❌ %s\n" "$*" >&2; }
run(){ if [ "$DRY_RUN" = "1" ]; then printf "↪ DRY-RUN: %s\n" "$*"; else eval "$*"; fi }

# -------------------------
#      Small utilities
# -------------------------
ensure_dir(){ [ -d "$1" ] || mkdir -p "$1"; }

backup_if_exists(){
  local f="$1"
  if [ -e "$f" ] && [ ! -e "${f}.bak" ]; then
    cp -a "$f" "${f}.bak.$(date +%Y%m%d%H%M%S)"
    log_i "Backed up $f -> ${f}.bak.*"
  fi
}

append_block_if_missing(){
  # args: file, start_marker, end_marker, stdin=block
  local file="$1" start="$2" end="$3" tmp
  tmp="$(mktemp)"
  cat > "$tmp"
  if [ -f "$file" ] && grep -Fq "$start" "$file"; then
    rm -f "$tmp"
    return 0
  fi
  {
    printf "\n%s\n" "$start"
    cat "$tmp"
    printf "%s\n" "$end"
  } >> "$file"
  rm -f "$tmp"
}

detect_rc_file(){
  # Prefer zsh if running zsh; else bash
  if echo "${SHELL:-}" | grep -qi "zsh"; then
    echo "${HOME_DIR}/.zshrc"
  else
    # bash: prefer .bashrc, fall back to .bash_profile
    if [ -f "${HOME_DIR}/.bashrc" ] || [ ! -f "${HOME_DIR}/.bash_profile" ]; then
      echo "${HOME_DIR}/.bashrc"
    else
      echo "${HOME_DIR}/.bash_profile"
    fi
  fi
}

# -------------------------
#      Up-to-date check
# -------------------------
uptodate_summary(){
  local have_node="no" have_cli="no" have_profiles="no" have_block="no"
  command -v node >/dev/null 2>&1 && have_node="yes"
  command -v claude >/dev/null 2>&1 && have_cli="yes"
  [ -f "${PROFILES_DIR}/anthropic.json" ] && [ -f "${PROFILES_DIR}/zai.json" ] && have_profiles="yes"
  local rc; rc="$(detect_rc_file)"; [ -f "$rc" ] && grep -Fq "# >>> claude-profiles >>>" "$rc" && have_block="yes"
  printf "Up-to-date: node=%s, claude-cli=%s, profiles=%s, rc-block=%s\n" "$have_node" "$have_cli" "$have_profiles" "$have_block"
  [ "$have_node" = yes ] && [ "$have_cli" = yes ] && [ "$have_profiles" = yes ] && [ "$have_block" = yes ]
}

# -------------------------
#         Doctor
# -------------------------
doctor(){
  echo "🩺 Running diagnostics…"
  command -v curl >/dev/null 2>&1 || log_err "curl not found"
  command -v npm  >/dev/null 2>&1 || log_err "npm not found (will install Node via nvm if needed)"
  command -v node >/dev/null 2>&1 && echo "Node: $(node -v)" || echo "Node: missing"
  command -v claude >/dev/null 2>&1 && echo "Claude: $(claude --version 2>/dev/null || true)" || echo "Claude: missing"
  [ -d "$CLAUDE_DIR" ] && echo "Claude dir: $CLAUDE_DIR" || echo "Claude dir: missing (will create)"
  [ -f "${PROFILES_DIR}/anthropic.json" ] && echo "Profile: anthropic.json present" || echo "Profile: anthropic.json missing"
  [ -f "${PROFILES_DIR}/zai.json" ] && echo "Profile: zai.json present" || echo "Profile: zai.json missing"
  local rc; rc="$(detect_rc_file)"; if [ -f "$rc" ]; then
    if grep -Fq "# >>> claude-profiles >>>" "$rc"; then echo "RC block: present ($rc)"; else echo "RC block: missing ($rc)"; fi
  else
    echo "RC file: not found ($rc will be created)"
  fi
  if [ -n "${HTTP_PROXY:-}${HTTPS_PROXY:-}${http_proxy:-}${https_proxy:-}" ]; then
    echo "Proxy detected; configure npm proxy via 'npm config set proxy/https-proxy' if installs fail."
  fi
}

# -------------------------
#        Uninstall
# -------------------------
uninstall_all(){
  echo "🧹 Uninstalling Claude profiles setup…"
  local rc; rc="$(detect_rc_file)"
  if [ -f "$rc" ] && grep -Fq "# >>> claude-profiles >>>" "$rc"; then
    if [ "$DRY_RUN" = "1" ]; then
      log_i "Would remove RC block from $rc"
    else
      awk 'BEGIN{s=1} /# >>> claude-profiles >>>/{s=0} s==1{print} /# <<< claude-profiles <<</{s=1}' "$rc" > "${rc}.tmp" && mv "${rc}.tmp" "$rc"
      log_ok "Removed RC block from $rc"
    fi
  fi
  if [ -e "$SETTINGS_SYMLINK" ]; then
    [ "$DRY_RUN" = "1" ] || rm -f "$SETTINGS_SYMLINK"
    log_ok "Removed $SETTINGS_SYMLINK"
  fi
  if [ -d "$PROFILES_DIR" ]; then
    [ "$DRY_RUN" = "1" ] || rm -f "${PROFILES_DIR}/"*.json
    log_ok "Removed profiles in $PROFILES_DIR (kept directory)"
  fi
  if [ -d "$CLAUDE_BIN_DIR" ]; then
    [ "$DRY_RUN" = "1" ] || rm -f "${CLAUDE_BIN_DIR}/get-anthropic-key" "${CLAUDE_BIN_DIR}/get-zai-key"
    log_ok "Removed helper scripts"
  fi
  log_ok "Uninstall complete. You may also remove ~/.claude manually if desired."
}
# -------------------------
#   Node + nvm bootstrap
# -------------------------
install_node_if_needed(){
  local node_ok="0"
  if command -v node >/dev/null 2>&1; then
    local v major
    v="$(node -v 2>/dev/null | sed 's/^v//')"
    major="${v%%.*}"
    if [ -n "$major" ] && [ "$major" -ge "$NODE_MIN_VERSION" ]; then
      node_ok="1"
      log_ok "Node.js present (v${v})"
    fi
  fi

  if [ "$node_ok" = "0" ]; then
    case "$SCRIPT_OS" in
      Linux|Darwin)
        log_i "Installing Node.js via nvm ($NVM_VERSION), target v$NODE_INSTALL_VERSION…"
        if [ "$DRY_RUN" = "1" ]; then
          log_i "Would fetch and run nvm installer"
        else
          curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
        fi
        export NVM_DIR="$HOME_DIR/.nvm"
        # shellcheck disable=SC1090
        [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
        [ "$DRY_RUN" = "1" ] || nvm install "$NODE_INSTALL_VERSION"
        [ "$DRY_RUN" = "1" ] || nvm alias default "$NODE_INSTALL_VERSION"
        [ "$DRY_RUN" = "1" ] || nvm use default >/dev/null
        log_ok "Node: $(command -v node >/dev/null 2>&1 && node -v || echo "v$NODE_INSTALL_VERSION"), npm: $(command -v npm >/dev/null 2>&1 && npm -v || echo '?')"
        ;;
      *)
        log_err "Unsupported platform: $SCRIPT_OS"
        exit 1
        ;;
    esac
  fi
}

# -------------------------
#     Claude Code CLI
# -------------------------
install_claude_cli(){
  if command -v claude >/dev/null 2>&1; then
    log_ok "Claude Code already installed: $(claude --version 2>/dev/null || echo '?')"
  else
    log_i "Installing Claude Code CLI globally…"
    if [ "$DRY_RUN" = "1" ]; then
      log_i "Would run: npm install -g $CLAUDE_NPM_PKG"
    else
      if ! npm install -g "$CLAUDE_NPM_PKG"; then
        log_err "npm install failed. If using a proxy, configure npm proxy settings. Trying npx fallback…"
        if ! npx --yes "$CLAUDE_NPM_PKG" --version >/dev/null 2>&1; then
          log_err "npx fallback also failed. Please ensure network connectivity and npm setup, then rerun."
          exit 1
        fi
      fi
      log_ok "Installed Claude Code: $(claude --version 2>/dev/null || echo 'installed via npx')"
    fi
  fi
}

# -------------------------
#  Onboarding skip toggle
# -------------------------
set_onboarding_flag(){
  # Keep everything else in ~/.claude.json intact; just enforce hasCompletedOnboarding: true
  backup_if_exists "$ONBOARD_FILE"
  if [ "$DRY_RUN" = "1" ]; then
    log_i "Would set hasCompletedOnboarding=true in ${ONBOARD_FILE}"
    return 0
  fi
  node >/dev/null 2>&1 <<'NODE'
const fs = require('fs');
const os = require('os');
const p = require('path');
const f = p.join(os.homedir(), '.claude.json');
let obj = {};
try { if (fs.existsSync(f)) obj = JSON.parse(fs.readFileSync(f,'utf8')); } catch {}
obj.hasCompletedOnboarding = true;
fs.writeFileSync(f, JSON.stringify(obj, null, 2), 'utf8');
NODE
  chmod 600 "$ONBOARD_FILE" 2>/dev/null || true
  log_ok "Onboarding flag set in ${ONBOARD_FILE}"
}

# -------------------------
#   Helper scripts (no secrets on disk)
# -------------------------
create_helpers(){
  ensure_dir "$CLAUDE_BIN_DIR"

  # POSIX /bin/sh scripts so apiKeyHelper can call them
  cat > "${CLAUDE_BIN_DIR}/get-anthropic-key" <<'SH'
#!/bin/sh
# Emits an Anthropic API key to stdout, or exits non-zero if not available.
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  printf "%s" "$ANTHROPIC_API_KEY"; exit 0
fi
if command -v pass >/dev/null 2>&1; then
  pass show api/anthropic 2>/dev/null && exit 0
fi
case "$(uname -s)" in
  Darwin)
    if command -v security >/dev/null 2>&1; then
      security find-generic-password -s anthropic_api_key -w 2>/dev/null && exit 0
    fi
    ;;
esac
exit 1
SH

  cat > "${CLAUDE_BIN_DIR}/get-zai-key" <<'SH'
#!/bin/sh
# Emits a Z.ai API key to stdout, or exits non-zero if not available.
if [ -n "${ZAI_API_KEY:-}" ]; then
  printf "%s" "$ZAI_API_KEY"; exit 0
fi
if command -v pass >/dev/null 2>&1; then
  pass show api/zai 2>/dev/null && exit 0
fi
case "$(uname -s)" in
  Darwin)
    if command -v security >/dev/null 2>&1; then
      security find-generic-password -s zai_api_key -w 2>/dev/null && exit 0
    fi
    ;;
esac
exit 1
SH

  chmod 700 "${CLAUDE_BIN_DIR}/get-anthropic-key" "${CLAUDE_BIN_DIR}/get-zai-key"
  log_ok "Helper scripts created in ${CLAUDE_BIN_DIR}/"
}

# -------------------------
#     Profile JSON files
# -------------------------
create_profiles(){
  ensure_dir "$PROFILES_DIR"

  # anthropic profile
  if [ ! -f "${PROFILES_DIR}/anthropic.json" ]; then
    if [ "$DRY_RUN" = "1" ]; then log_i "Would create anthropic.json"; else node >/dev/null 2>&1 <<NODE
const fs = require('fs');
const os = require('os');
const p = require('path');
const dir = p.join(os.homedir(), '.claude', 'profiles');
const helper = p.join(os.homedir(), '.claude', 'bin', 'get-anthropic-key');
const cfg = {
  apiKeyHelper: helper,
  permissions: {
    deny: [
      "Read(./.env)",
      "Read(./.env.*)",
      "Read(./secrets/**)"
    ]
  },
  env: {
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"
  }
};
fs.writeFileSync(p.join(dir, 'anthropic.json'), JSON.stringify(cfg, null, 2));
NODE
    fi
    log_ok "Created profile: anthropic"
  else
    log_i "Profile already exists: anthropic"
  fi

  # zai profile (Anthropic-compatible endpoint)
  if [ ! -f "${PROFILES_DIR}/zai.json" ]; then
    if [ "$DRY_RUN" = "1" ]; then log_i "Would create zai.json"; else node >/dev/null 2>&1 <<NODE
const fs = require('fs');
const os = require('os');
const p = require('path');
const dir = p.join(os.homedir(), '.claude', 'profiles');
const helper = p.join(os.homedir(), '.claude', 'bin', 'get-zai-key');
const cfg = {
  apiKeyHelper: helper,
  permissions: {
    deny: [
      "Read(./.env)",
      "Read(./.env.*)",
      "Read(./secrets/**)"
    ]
  },
  env: {
    "ANTHROPIC_BASE_URL": "https://api.z.ai/api/anthropic",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"
  }
};
fs.writeFileSync(p.join(dir, 'zai.json'), JSON.stringify(cfg, null, 2));
NODE
    fi
    log_ok "Created profile: zai"
  else
    log_i "Profile already exists: zai"
  fi

  # Default link (anthropic) if no settings.json yet
  if [ ! -e "$SETTINGS_SYMLINK" ]; then
    [ "$DRY_RUN" = "1" ] || ln -sf "${PROFILES_DIR}/anthropic.json" "$SETTINGS_SYMLINK"
    log_ok "Linked ${SETTINGS_SYMLINK} -> profiles/anthropic.json"
  fi
}

# -------------------------
#   Shell functions / RC
# -------------------------
install_shell_functions(){
  local rc
  rc="$(detect_rc_file)"
  ensure_dir "$(dirname "$rc")"
  backup_if_exists "$rc"

  if [ "$DRY_RUN" = "1" ]; then
    log_i "Would append shell helpers block to ${rc}"
  else
    append_block_if_missing "$rc" \
      "# >>> claude-profiles >>>" \
      "# <<< claude-profiles <<<" <<'RC'
# Claude Code profile switcher + helpers
cc-profile() {
  # persistent switch via symlink (~/.claude/settings.json)
  local name="$1"
  if [ -z "$name" ]; then
    echo "usage: cc-profile anthropic|zai" >&2; return 2
  fi
  local src="$HOME/.claude/profiles/${name}.json"
  if [ ! -f "$src" ]; then
    echo "No such profile: $name" >&2; return 1
  fi
  ln -sf "$src" "$HOME/.claude/settings.json"
  echo "Claude Code profile -> $name"
}

# One-shot (no file edits); sets env only for this invocation
cc-use() {
  local provider="$1"; shift || true
  local force="0"
  if [ "$provider" = "--force" ]; then
    provider="$1"; shift || true; force="1"
  fi
  if [ -z "${provider}" ] || [ "${provider}" = "--help" ] || [ "${provider}" = "-h" ]; then
    echo "usage: cc-use anthropic|zai [-- args-to-claude]" >&2; return 2
  fi
  case "$provider" in
    anthropic)
      if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
        if command -v pass >/dev/null 2>&1; then
          ANTHROPIC_API_KEY="$(pass show api/anthropic 2>/dev/null || true)"
        fi
        if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
          printf "🔑 Enter Anthropic API key: " >&2
          stty -echo; IFS= read -r ANTHROPIC_API_KEY; stty echo; printf "\n" >&2
        fi
      fi
      # ensure Anthropic path is clean of Z.ai env
      # optional: temporarily point settings to matching profile
      local prev_link
      if [ "$force" = "1" ]; then
        prev_link="$(readlink "$HOME/.claude/settings.json" 2>/dev/null || true)"
        ln -sf "$HOME/.claude/profiles/anthropic.json" "$HOME/.claude/settings.json"
      fi
      CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
      ANTHROPIC_BASE_URL="" \
      ANTHROPIC_AUTH_TOKEN="" \
      ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
      claude "$@"
      if [ "$force" = "1" ] && [ -n "$prev_link" ]; then ln -sf "$prev_link" "$HOME/.claude/settings.json"; fi
      ;;
    zai)
      if [ -z "${ZAI_API_KEY:-}" ]; then
        if command -v pass >/dev/null 2>&1; then
          ZAI_API_KEY="$(pass show api/zai 2>/dev/null || true)"
        fi
        if [ -z "${ZAI_API_KEY:-}" ]; then
          printf "🔑 Enter Z.ai API key: " >&2
          stty -echo; IFS= read -r ZAI_API_KEY; stty echo; printf "\n" >&2
        fi
      fi
      # optional: temporarily point settings to matching profile
      local prev_link
      if [ "$force" = "1" ]; then
        prev_link="$(readlink "$HOME/.claude/settings.json" 2>/dev/null || true)"
        ln -sf "$HOME/.claude/profiles/zai.json" "$HOME/.claude/settings.json"
      fi
      CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
      ANTHROPIC_BASE_URL="$ZAI_BASE_URL" \
      ANTHROPIC_AUTH_TOKEN="$ZAI_API_KEY" \
      claude "$@"
      if [ "$force" = "1" ] && [ -n "$prev_link" ]; then ln -sf "$prev_link" "$HOME/.claude/settings.json"; fi
      ;;
    *)
      echo "usage: cc-use anthropic|zai [-- args-to-claude]" >&2; return 2 ;;
  esac
}

# Convenience wrappers that also persist the profile symlink
claude-anthropic(){ cc-profile anthropic >/dev/null 2>&1 || true; cc-use anthropic "$@"; }
claude-glm(){ cc-profile zai >/dev/null 2>&1 || true; cc-use zai "$@"; }
RC
  fi

  log_ok "Shell helpers added to ${rc}"
}

# -------------------------
#      direnv template
# -------------------------
install_direnv_template(){
  if [ "$WITH_DIRENV" != "1" ]; then return 0; fi
  local rc
  rc="$(detect_rc_file)"

  if command -v direnv >/dev/null 2>&1; then
    if [ "$DRY_RUN" = "1" ]; then
      log_i "Would ensure direnv hook in ${rc}"
    else
      append_block_if_missing "$rc" \
        "# >>> direnv (claude) >>>" \
        "# <<< direnv (claude) <<<" <<'RC'
eval "$(direnv hook bash 2>/dev/null || direnv hook zsh 2>/dev/null)"
RC
    fi
    log_ok "direnv hook ensured in ${rc}"
  else
    log_i "direnv not found; skipping hook (install later with brew/apt/pacman)."
  fi

  ensure_dir "${CLAUDE_DIR}/examples"
  if [ "$DRY_RUN" = "1" ]; then
    log_i "Would write direnv template to ${CLAUDE_DIR}/examples/.envrc.claude"
  else
    cat > "${CLAUDE_DIR}/examples/.envrc.claude" <<'ENVRC'
# Example per-repo switch with direnv (copy to your project as .envrc, then `direnv allow`)
# Choose provider for this repo:
# export CLAUDE_PROVIDER="anthropic"
export CLAUDE_PROVIDER="zai"

# Provider-specific env (no secrets here)
if [ "${CLAUDE_PROVIDER}" = "zai" ]; then
  export ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic"
  # optional model mappings for Z.ai (usually omit to follow defaults)
  # export ANTHROPIC_DEFAULT_SONNET_MODEL="glm-4.6"
  # export ANTHROPIC_DEFAULT_HAIKU_MODEL="glm-4.5-air"
else
  unset ANTHROPIC_BASE_URL
fi

# Privacy/ops hygiene
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1

# Bring secrets from your store (uncomment one)
# if command -v pass >/dev/null 2>&1; then
#   [ "${CLAUDE_PROVIDER}" = "zai" ] && export ZAI_API_KEY="$(pass show api/zai)"
#   [ "${CLAUDE_PROVIDER}" = "anthropic" ] && export ANTHROPIC_API_KEY="$(pass show api/anthropic)"
# fi
# macOS Keychain examples (store once with: security add-generic-password -a "$USER" -s zai_api_key -w)
# [ "${CLAUDE_PROVIDER}" = "zai" ] && export ZAI_API_KEY="$(security find-generic-password -s zai_api_key -w 2>/dev/null || true)"
# [ "${CLAUDE_PROVIDER}" = "anthropic" ] && export ANTHROPIC_API_KEY="$(security find-generic-password -s anthropic_api_key -w 2>/dev/null || true)"

# optional: expose a helper to run Claude using env-only switching
export CLAUDE_LAUNCH="cc-use ${CLAUDE_PROVIDER}"
ENVRC
  fi

  log_ok "Wrote direnv template to ${CLAUDE_DIR}/examples/.envrc.claude"
}

# -------------------------
#           Main
# -------------------------
main(){
  printf "🚀 Claude Code bootstrap starting… (v%s)\n" "$SCRIPT_VERSION"

  if [ "$DO_DOCTOR" = "1" ]; then doctor; exit 0; fi
  if [ "$DO_UNINSTALL" = "1" ]; then uninstall_all; exit 0; fi

  umask 077
  ensure_dir "$CLAUDE_DIR"
  install_node_if_needed
  install_claude_cli
  set_onboarding_flag
  create_helpers
  create_profiles
  install_shell_functions
  install_direnv_template

  printf "\n"
  log_ok "Setup complete."
  printf "\nNext steps:\n"
  printf "  • Open a new terminal (or source your shell rc) so functions are loaded.\n"
  printf "  • Persistent default:   cc-profile anthropic   # or: cc-profile zai\n"
  printf "  • One-off run:          cc-use anthropic -- /status\n"
  printf "                          cc-use zai -- /status\n"
  printf "  • Convenience:          claude-anthropic, claude-glm\n"
  if [ "$WITH_DIRENV" = "1" ]; then
    printf "  • direnv template: copy %s/examples/.envrc.claude into your repo and run: direnv allow\n" "$CLAUDE_DIR"
  fi
}
main "$@"

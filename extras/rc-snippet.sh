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
      CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
      ANTHROPIC_BASE_URL="" \
      ANTHROPIC_AUTH_TOKEN="" \
      ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
      claude "$@"
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
      CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
      ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic" \
      ANTHROPIC_AUTH_TOKEN="$ZAI_API_KEY" \
      claude "$@"
      ;;
    *)
      echo "usage: cc-use anthropic|zai [-- args-to-claude]" >&2; return 2 ;;
  esac
}

# Convenience wrappers that also persist the profile symlink
claude-anthropic(){ cc-profile anthropic >/dev/null 2>&1 || true; cc-use anthropic "$@"; }
claude-glm(){ cc-profile zai >/dev/null 2>&1 || true; cc-use zai "$@"; }

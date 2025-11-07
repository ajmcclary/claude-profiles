#!/usr/bin/env bash
# cc-use: run Claude Code with either 'anthropic' or 'zai'
cc-use() {
  set -euo pipefail
  local provider="${1:-}"
  local force="0"
  if [[ "$provider" == "--force" ]]; then
    provider="${2:-}"; shift; force="1"
  fi
  if [[ -z "$provider" || "$provider" == "--help" || "$provider" == "-h" ]]; then
    echo "usage: cc-use anthropic|zai [-- args to claude]" >&2
    return 2
  fi

  case "$provider" in
    anthropic)
      unset ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL
      : "${ANTHROPIC_API_KEY:=$(pass show api/anthropic 2>/dev/null || true)}"
      if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
        read -rsp "Enter Anthropic API key: " ANTHROPIC_API_KEY; echo
      fi
      # optional: temporarily point settings to matching profile
      local prev_link
      if [[ "$force" == "1" ]]; then
        prev_link="$(readlink "$HOME/.claude/settings.json" 2>/dev/null || true)"
        ln -sf "$HOME/.claude/profiles/anthropic.json" "$HOME/.claude/settings.json"
      fi
      export ANTHROPIC_API_KEY
      claude "${@:2}"
      if [[ "$force" == "1" && -n "$prev_link" ]]; then ln -sf "$prev_link" "$HOME/.claude/settings.json"; fi
      ;;
    zai)
      export ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic"
      : "${ZAI_API_KEY:=$(pass show api/zai 2>/dev/null || true)}"
      if [[ -z "${ZAI_API_KEY:-}" ]]; then
        read -rsp "Enter Z.ai API key: " ZAI_API_KEY; echo
      fi
      # optional: temporarily point settings to matching profile
      local prev_link
      if [[ "$force" == "1" ]]; then
        prev_link="$(readlink "$HOME/.claude/settings.json" 2>/dev/null || true)"
        ln -sf "$HOME/.claude/profiles/zai.json" "$HOME/.claude/settings.json"
      fi
      export ANTHROPIC_AUTH_TOKEN="$ZAI_API_KEY"
      claude "${@:2}"
      if [[ "$force" == "1" && -n "$prev_link" ]]; then ln -sf "$prev_link" "$HOME/.claude/settings.json"; fi
      ;;
    *)
      echo "unknown provider: $provider (use anthropic|zai)" >&2; return 2;;
  esac

  export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
  # default call path is handled above per-provider
}

# Convenience wrappers
claude-anthropic(){ cc-use anthropic "$@"; }
claude-glm(){ cc-use zai "$@"; }

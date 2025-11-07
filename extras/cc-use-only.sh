#!/usr/bin/env bash
# cc-use: run Claude Code with either 'anthropic' or 'zai'
cc-use() {
  set -euo pipefail
  local provider="${1:-}"
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
      export ANTHROPIC_API_KEY
      ;;
    zai)
      export ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic"
      : "${ZAI_API_KEY:=$(pass show api/zai 2>/dev/null || true)}"
      if [[ -z "${ZAI_API_KEY:-}" ]]; then
        read -rsp "Enter Z.ai API key: " ZAI_API_KEY; echo
      fi
      export ANTHROPIC_AUTH_TOKEN="$ZAI_API_KEY"
      ;;
    *)
      echo "unknown provider: $provider (use anthropic|zai)" >&2; return 2;;
  esac

  export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
  claude "${@:2}"
}

# Convenience wrappers
claude-anthropic(){ cc-use anthropic "$@"; }
claude-glm(){ cc-use zai "$@"; }

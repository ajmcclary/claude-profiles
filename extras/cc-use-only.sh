#!/usr/bin/env bash
# cc-use: run Claude Code with either 'anthropic' or 'zai'
_cc_prompt_secret(){
  local prompt="$1" secret
  printf "%s" "$prompt" >&2
  if command -v stty >/dev/null 2>&1; then
    secret="$(
      stty -echo
      trap 'stty echo; exit 130' INT TERM
      trap 'stty echo' EXIT
      IFS= read -r _value || exit 1
      printf "%s" "$_value"
    )" || return 1
  else
    IFS= read -r secret || return 1
  fi
  printf "\n" >&2
  printf "%s" "${secret:-}"
}

cc-use() {
  local force="0"
  if [[ "${1:-}" == "--force" ]]; then
    force="1"
    shift || true
  fi

  local provider="${1:-}"
  if [[ -z "$provider" || "$provider" == "--help" || "$provider" == "-h" ]]; then
    echo "usage: cc-use anthropic|zai [-- args to claude]" >&2
    return 2
  fi
  shift || true

  local settings_path="$HOME/.claude/settings.json"
  local prev_link="" restore_link="0" status=0

  case "$provider" in
    anthropic)
      unset ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL
      if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
        if command -v pass >/dev/null 2>&1; then
          ANTHROPIC_API_KEY="$(pass show api/anthropic 2>/dev/null || true)"
        fi
        if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
          local entered
          entered="$(_cc_prompt_secret "🔑 Enter Anthropic API key: ")" || return $?
          if [[ -z "$entered" ]]; then
            echo "Anthropic API key is required" >&2
            return 1
          fi
          ANTHROPIC_API_KEY="$entered"
        fi
      fi
      if [[ "$force" == "1" ]]; then
        prev_link="$(readlink "$settings_path" 2>/dev/null || true)"
        ln -sf "$HOME/.claude/profiles/anthropic.json" "$settings_path"
        restore_link="1"
      fi
      CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
      ANTHROPIC_BASE_URL="" \
      ANTHROPIC_AUTH_TOKEN="" \
      ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
      claude "$@"
      status=$?
      ;;
    zai)
      if [[ -z "${ZAI_API_KEY:-}" ]]; then
        if command -v pass >/dev/null 2>&1; then
          ZAI_API_KEY="$(pass show api/zai 2>/dev/null || true)"
        fi
        if [[ -z "${ZAI_API_KEY:-}" ]]; then
          local entered
          entered="$(_cc_prompt_secret "🔑 Enter Z.ai API key: ")" || return $?
          if [[ -z "$entered" ]]; then
            echo "Z.ai API key is required" >&2
            return 1
          fi
          ZAI_API_KEY="$entered"
        fi
      fi
      if [[ "$force" == "1" ]]; then
        prev_link="$(readlink "$settings_path" 2>/dev/null || true)"
        ln -sf "$HOME/.claude/profiles/zai.json" "$settings_path"
        restore_link="1"
      fi
      CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
      ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic" \
      ANTHROPIC_AUTH_TOKEN="$ZAI_API_KEY" \
      claude "$@"
      status=$?
      ;;
    *)
      echo "unknown provider: $provider (use anthropic|zai)" >&2
      return 2
      ;;
  esac

  if [[ "$restore_link" == "1" && -n "$prev_link" ]]; then
    ln -sf "$prev_link" "$settings_path"
  fi
  return "$status"
}

# Convenience wrappers
claude-anthropic(){ cc-use anthropic "$@"; }
claude-glm(){ cc-use zai "$@"; }

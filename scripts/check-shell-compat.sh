#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash_files=(
  "install-claude-profiles.sh"
  "extras/rc-snippet.sh"
  "extras/cc-use-only.sh"
  "scripts/make-demo.sh"
)

zsh_files=(
  "extras/rc-snippet.sh"
  "extras/cc-use-only.sh"
)

echo "Checking bash syntax..."
for rel in "${bash_files[@]}"; do
  file="${ROOT_DIR}/${rel}"
  if [[ ! -f "$file" ]]; then
    echo "Missing file: $rel" >&2
    exit 1
  fi
  bash -n "$file"
done

echo "Checking zsh syntax..."
if ! command -v zsh >/dev/null 2>&1; then
  echo "zsh is required for compatibility checks" >&2
  exit 1
fi
for rel in "${zsh_files[@]}"; do
  file="${ROOT_DIR}/${rel}"
  zsh -n "$file"
done

echo "Shell compatibility checks passed."

#!/usr/bin/env bash
set -euo pipefail

out_dir="docs"
cast_file="${out_dir}/demo.cast"
svg_file="${out_dir}/demo-switch.svg"

echo "Checking dependencies..."
command -v asciinema >/dev/null 2>&1 || { echo "asciinema not found. Install: brew install asciinema (macOS) or pipx install asciinema"; exit 1; }
command -v npx >/dev/null 2>&1 || { echo "npx not found. Install Node.js (nvm or system)"; exit 1; }

echo "Preparing output directory: ${out_dir}"
mkdir -p "$out_dir"

cat <<'HINT'
Recording demo. In the new shell, run commands like:
  cc-profile anthropic && claude --version
  cc-use zai -- /status
  cc-use anthropic -- /status
  claude-glm -- /status
Press Ctrl-D to finish recording.
HINT

asciinema rec -c "bash -l" "$cast_file"

echo "Converting to SVG via svg-term..."
npx --yes svg-term --cast "$cast_file" --out "$svg_file" --window

echo "Demo generated: $svg_file"
echo "README references docs/demo-switch.svg."

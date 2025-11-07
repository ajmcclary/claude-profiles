# Demo Assets

This folder contains the animated terminal walkthrough used in the main README.

Generate or update the demo SVG:

```bash
bash scripts/make-demo.sh
```

Requirements:
- `asciinema` (macOS: `brew install asciinema`, or `pipx install asciinema`)
- `npx` (Node.js installed via system or nvm)

Outputs:
- `docs/demo.cast` — raw recording (portable)
- `docs/demo-switch.svg` — embeddable animation used in README

Tips:
- Keep the session short and focused (switch default, run one-off, quick status).
- Avoid showing secret material; the helpers will prompt with hidden input.

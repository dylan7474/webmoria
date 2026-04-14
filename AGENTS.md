# AGENTS.md

Guidance for AI coding agents working in this repository.

## Project overview

- This project is intentionally simple: a single-file browser game in `moria.html`.
- Prefer small, targeted edits over broad refactors.
- Keep the game playable by opening the file directly in a browser.

## Coding guidelines

- Preserve keyboard-first gameplay and classic roguelike feel.
- Avoid introducing heavy build tooling unless explicitly requested.
- Keep new dependencies to a minimum (ideally none).
- Prefer readable, plain JavaScript over framework abstractions.

## Documentation expectations

- Update `README.md` whenever controls or run instructions change.
- Keep controls documented in a concise, scannable list.
- Add a short changelog-style note in PR descriptions for gameplay-impacting changes.

## Testing and validation

- At minimum, perform a quick manual smoke check:
  - game loads,
  - player can move,
  - one interaction key works (inventory/shop/stairs),
  - no obvious console errors.

## Pull request checklist

- Explain what changed and why.
- List manual testing done.
- Note any follow-up work or known limitations.

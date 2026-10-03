# Black Box — current development brief

The active application is v0.2, split into backend/ and frontend/. Read README.md, backend/README.md, frontend/README.md and backend/docs/MIGRATION.md first.

## Architecture

- Go owns all simulation and business rules.
- Fiber exposes a WebSocket command/snapshot protocol.
- GORM and SQLite persist complete resumable state and observation history.
- React, TypeScript and Tailwind own the interface.
- Pixi.js draws terrain, objects, people and animation.
- Generate TypeScript types from backend/internal/protocol. Do not maintain a second model manually.
- Keep RNG-consuming decisions and resource competition deterministic.
- Use goroutines for independent work and bounded IO, with explicit ownership of mutable state.

## Design knowledge

The complete original design brief is preserved verbatim at [backend/docs/legacy/PROMPT.md](backend/docs/legacy/PROMPT.md). Its economic principles, formulas, rationale and comments remain the reference for game behavior. Its Odin/raylib build instructions describe the archived version.

The original README, extracted source comments, assets and tools are preserved beside that brief. Odin source and tests were removed after verifying the Go port. The migration document maps the systems to their new locations and records the parity checks; the independent Odin-generated fixture remains in the Go tests.

## Validation

Run backend tests and the frontend production build. Keep the Odin fixture independent of Go output. When changing simulation rules intentionally, document the difference and update the relevant behavioral tests; never silently change the fixture to hide a regression.

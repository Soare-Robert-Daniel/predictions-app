# Architecture

Architecture notes, patterns, and implementation guidance for workers.

**What belongs here:** Context boundaries, major design decisions, persistence patterns, and cross-cutting rules.  
**What does NOT belong here:** Commands/ports; use `.factory/services.yaml`.

---

- The codebase starts from a near-fresh Phoenix skeleton. Workers should establish clear domain boundaries instead of adding ad hoc modules.
- Prefer a small set of clear contexts:
  - `Predictions.Accounts` for authentication and role handling
  - `Predictions.Markets` for markets, options, votes, and resolution logic
  - `Predictions.Notifications` for in-app notifications if a separate context is helpful
- Use Phoenix/LiveView-native flows for the UI; keep forms and interaction patterns aligned with the repo `AGENTS.md`.
- Enforce key invariants in both domain logic and persistence constraints where possible:
  - one vote per user per market
  - admin users cannot vote
  - invalid market submissions leave no partial rows
  - resolution checks are idempotent
- Automatic market resolution must work within the approved boundaries: no extra infrastructure, no Docker, SQLite only.
- When a feature needs lifecycle state in the UI, make the state explicit and consistent across list/detail surfaces: upcoming, active, resolved.

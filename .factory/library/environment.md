# Environment

Environment variables, external dependencies, and setup notes.

**What belongs here:** Required env vars, external services, dependency quirks, platform-specific notes.  
**What does NOT belong here:** Service ports/commands; use `.factory/services.yaml`.

---

- Runtime stack: Phoenix 1.8, LiveView, Ecto, SQLite.
- Local app URL: `http://127.0.0.1:4000`.
- Primary local database files are SQLite files in the repo root.
- Docker is not available in this environment and is out of scope for this mission.
- Bun `1.3.9` is installed on the machine, but the project does not depend on Bun for its main runtime flow.
- Browser automation remains unavailable for this mission because the planning dry run showed the current `agent-browser` path explicitly requires `npm`, which is not installed.

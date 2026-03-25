# User Testing

Validation surface, tool choices, and concurrency limits for this mission.

**What belongs here:** Testable surfaces, runtime validation method, setup expectations, concurrency limits, and known limitations.  
**What does NOT belong here:** Build/test command definitions; use `.factory/services.yaml`.

---

## Validation Surface

- Primary validation surface: Phoenix automated tests plus HTTP-level runtime checks against `http://127.0.0.1:4000`.
- Start the app with the `web` service from `.factory/services.yaml` when runtime checks are needed.
- Prefer runtime checks that verify:
  - auth redirects and protected-route access
  - market authoring reachability and success/failure responses
  - vote submission success/failure responses
  - resolved market pages
  - notification inbox and deep-link reachability

## Accepted Limitations

- The user explicitly approved proceeding without browser automation.
- Planning dry run confirmed the app can start and serve locally, but the `agent-browser` path is blocked because it expects `npm`, which is not installed.
- Bun `1.3.9` is installed, but it does not remove the above limitation for this mission.

## Validation Concurrency

- Machine profile observed during planning: 2 CPU cores, about 3.8 GB RAM.
- Use a conservative runtime validation concurrency of `1`.
- Keep `mix test` runs conservative with `--max-cases 1`.

## Runtime Notes

- HTTP smoke checks should target `127.0.0.1:4000`.
- Favor deterministic, role-aware fixtures so the same market can be exercised across admin creation, user voting, resolution, and notifications.

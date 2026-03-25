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

## Flow Validator Guidance: http

### Surface Description
HTTP-level validation against the Phoenix app at `http://127.0.0.1:4000`. Uses curl-style requests to verify auth redirects, protected-route access, session handling, and role-based access control.

### Isolation Rules
- Use the shared test users seeded in the dev database.
- Do NOT create additional users or modify existing user records.
- Each flow validator operates independently and should not interfere with others since only 1 validator runs at a time.

### Test Data
- Admin user: `admin@test.com` / `password123` (role: admin)
- Normal user: `user@test.com` / `password123` (role: user)

### Key Endpoints
- `GET /` - public home page
- `GET /sign-in` - sign-in page (public)
- `POST /sign-in` - submit credentials (creates session)
- `DELETE /sign-out` - end session
- `GET /dashboard` - user dashboard (requires signed-in user)
- `GET /admin` - admin dashboard (requires admin role)

### Session Handling
- Store cookies from POST /sign-in responses in a cookie jar for subsequent requests.
- Use `-c` and `-b` curl flags with a temporary cookie file per validator run.
- Session cookies contain the user_token key for authentication.

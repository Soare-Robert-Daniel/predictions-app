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
- Protected LiveView routes must be mounted through the browser pipeline / flash-aware setup; do not let conn-test flash helpers mask runtime route wiring problems.
- Enforce key invariants in both domain logic and persistence constraints where possible:
  - one vote per user per market
  - admin users cannot vote
  - invalid market submissions leave no partial rows
  - resolution checks are idempotent
- Automatic market resolution must work within the approved boundaries: no extra infrastructure, no Docker, SQLite only.
- When a feature needs lifecycle state in the UI, make the state explicit and consistent across list/detail surfaces: upcoming, active, resolved.

## Authentication Patterns

**Session key handling in on_mount callbacks:** Session keys can be serialized as either atoms or strings depending on how the session is accessed. Always handle both in on_mount callbacks:
```elixir
user_token = session[:user_token] || session["user_token"]
```
See `lib/predictions_web/plugs/auth.ex` for reference.

**Timing attack prevention:** Always use `Bcrypt.no_user_verify/0` when checking passwords for non-existent users to prevent timing attacks that could reveal which emails exist in the system:
```elixir
def valid_password?(%User{hashed_password: hashed_password}, password)
    when is_binary(hashed_password) and is_binary(password) do
  Bcrypt.verify_pass(password, hashed_password)
end

def valid_password?(_, _) do
  Bcrypt.no_user_verify()
  false
end
```

## Test Helpers

**login_user/1 helper:** The `login_user/1` helper in `test/support/conn_case.ex` creates a session token and sets it in the test session for simulating authenticated users:
```elixir
def login_user(%{conn: conn} = context) do
  user = Map.get(context, :user) || insert(:user)
  token = Accounts.create_user_session!(user)
  conn = Plug.Test.init_test_session(conn, user_token: token)
  %{conn: conn, user: user}
end
```
Use this pattern for any feature requiring authenticated test scenarios.

## LiveView Form Patterns

**Indexed form inputs:** When building dynamic form inputs with indexed names (e.g., `market[options][0][label]`, `market[options][1][label]`), LiveView form params arrive as maps with string keys, not lists. Handle both formats in changeset processing:

```elixir
defp cast_options(changeset, options) when is_list(options) do
  # Handle list format
end

defp cast_options(changeset, options) when is_map(options) do
  # Handle map format - convert to sorted list
  options
  |> Enum.sort_by(fn {idx, _} -> String.to_integer(idx) end)
  |> Enum.map(fn {_, params} -> params end)
  # ... then process as list
end
```

See `lib/predictions/markets/market.ex:118-132` for reference implementation.

---
name: phoenix-fullstack-worker
description: Implement Phoenix full-stack features spanning Ecto, LiveView/controllers, and HTTP-level verification.
---

# Phoenix Fullstack Worker

NOTE: Startup and cleanup are handled by `worker-base`. This skill defines the WORK PROCEDURE.

## When to Use This Skill

Use this skill for Phoenix features that span schema/context work, auth/authorization, LiveView or controller UI, lifecycle state presentation, and HTTP-verified flows in this repository.

## Required Skills

- `elixir-expert` — invoke at the start of work when implementing or changing Ecto schemas, migrations, LiveView flows, router wiring, or OTP-backed domain behavior so Phoenix/Elixir patterns stay idiomatic.

## Work Procedure

1. Read `mission.md`, mission `AGENTS.md`, `validation-contract.md`, the assigned feature in `features.json`, and the repo-root `AGENTS.md`. List the exact contract assertions this feature fulfills before changing code.
2. Inspect adjacent code and existing conventions before editing. Reuse existing layout, component, auth, and context patterns wherever possible.
3. Invoke `elixir-expert` before making code changes that touch Phoenix, Ecto, LiveView, routing, or OTP-backed resolution behavior.
4. Write failing automated tests first. Prefer:
   - context/schema tests for domain rules and persistence constraints
   - controller or LiveView tests for user-visible flows
   - explicit tests for authorization and mutation denial paths
   - race/replay tests where the contract requires one-vote safety
5. Only after seeing the failing tests, implement the smallest end-to-end slice needed to satisfy them. Keep business rules out of templates where possible.
6. Run focused tests during iteration until green.
7. Perform HTTP-level runtime verification for the fulfilled assertions. Use the local app on `http://127.0.0.1:4000`; do not rely on browser automation.
8. Run final validation in this order:
   - `mix format --check-formatted`
   - `mix compile --warnings-as-errors`
   - focused `mix test` commands for touched areas
   - `mix precommit`
9. Stop any long-running processes you started and confirm you did not leave orphaned services behind.
10. In the handoff, be explicit about which assertions were completed, which commands were run, which HTTP checks were performed, and any shortcuts or blockers you encountered.

## Example Handoff

```json
{
  "salientSummary": "Implemented the admin create-market LiveView on top of new market schemas and validations. Added failing market authoring tests first, then wired the form, create action, and authorization checks until focused tests and mix precommit passed. Verified the admin route over HTTP and confirmed guest and non-admin create attempts were rejected.",
  "whatWasImplemented": "Added market and market-option persistence, create-market LiveView routing, admin-only access control, form validation for blank questions, duplicate/insufficient options, invalid voting windows, and atomic rejection behavior for invalid submissions. The feature now satisfies the create-market form, valid submission, invalid submission, unauthorized submission, and atomicity assertions claimed by the assigned feature.",
  "whatWasLeftUndone": "",
  "verification": {
    "commandsRun": [
      {
        "command": "mix format --check-formatted",
        "exitCode": 0,
        "observation": "Formatting passed after the new LiveView, context, and test files were added."
      },
      {
        "command": "mix compile --warnings-as-errors",
        "exitCode": 0,
        "observation": "Compilation succeeded with no warnings."
      },
      {
        "command": "MIX_ENV=test mix test --max-cases 1 test/predictions/markets_test.exs test/predictions_web/live/admin_market_live_test.exs",
        "exitCode": 0,
        "observation": "Focused authoring tests passed, including authorization, validation, and atomicity cases."
      },
      {
        "command": "mix precommit",
        "exitCode": 0,
        "observation": "Final repo validation passed."
      }
    ],
    "interactiveChecks": [
      {
        "action": "Started the Phoenix app locally and requested the admin create-market route with an authenticated admin session.",
        "observed": "Route returned 200 and rendered the create-market form with question, options, and voting-window controls."
      },
      {
        "action": "Submitted a guest and a non-admin create-market request against the same route.",
        "observed": "Both requests were rejected and no market rows were created."
      }
    ]
  },
  "tests": {
    "added": [
      {
        "file": "test/predictions/markets_test.exs",
        "cases": [
          {
            "name": "create_market/2 persists trimmed options in order",
            "verifies": "valid market submissions store the expected question, options, and voting window"
          },
          {
            "name": "create_market/2 rejects duplicate or insufficient options",
            "verifies": "invalid option sets fail without persisting rows"
          }
        ]
      },
      {
        "file": "test/predictions_web/live/admin_market_live_test.exs",
        "cases": [
          {
            "name": "admin can open and submit create-market form",
            "verifies": "admin authoring UI works end-to-end"
          },
          {
            "name": "guest and non-admin submissions are rejected",
            "verifies": "server-side authorization protects create-market mutations"
          }
        ]
      }
    ]
  },
  "discoveredIssues": []
}
```

## When to Return to Orchestrator

- The feature depends on unresolved product decisions or route structures not covered by the mission artifacts.
- A required assertion cannot be completed within the approved boundaries (for example, it would require unapproved infrastructure).
- The current repo baseline or tooling is broken in a way that the feature cannot safely repair within scope.
- The feature reveals contract gaps that materially change what must be built or validated.

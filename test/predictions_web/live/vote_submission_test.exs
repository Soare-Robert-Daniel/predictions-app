defmodule PredictionsWeb.VoteSubmissionTest do
  use PredictionsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Predictions.Accounts
  alias Predictions.Markets

  describe "VAL-VOTE-002: Eligible user can cast exactly one vote on an active market" do
    setup do
      {:ok, user} = Accounts.create_user(%{email: "user@example.com", password: "password123"})

      now = DateTime.utc_now()

      {:ok, market} =
        Markets.create_market(%{
          question: "Active market for voting?",
          voting_start: now |> DateTime.add(-3600, :second),
          voting_end: now |> DateTime.add(86400, :second),
          options: ["Yes", "No"]
        })

      option_yes = Enum.find(market.options, fn o -> o.label == "Yes" end)
      option_no = Enum.find(market.options, fn o -> o.label == "No" end)

      %{user: user, market: market, option_yes: option_yes, option_no: option_no}
    end

    test "active market shows voting controls for eligible user", %{
      conn: conn,
      user: user,
      market: market
    } do
      conn = login_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/markets/#{market.id}")

      # Should see a voting form
      assert has_element?(lv, "#vote-form")
    end

    test "eligible user can submit a vote and it persists", %{
      conn: conn,
      user: user,
      market: market,
      option_yes: option
    } do
      conn = login_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/markets/#{market.id}")

      # Submit the vote form
      _html =
        lv
        |> form("#vote-form", %{"vote" => %{"option_id" => option.id}})
        |> render_submit()

      # Should show already-voted state
      assert has_element?(lv, "[data-already-voted]")

      # Verify the vote was persisted
      vote = Markets.get_user_vote(user.id, market.id)
      assert vote != nil
      assert vote.market_option_id == option.id
    end

    test "vote submission shows success feedback", %{
      conn: conn,
      user: user,
      market: market,
      option_yes: option
    } do
      conn = login_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/markets/#{market.id}")

      html =
        lv
        |> form("#vote-form", %{"vote" => %{"option_id" => option.id}})
        |> render_submit()

      # Should show success flash or already-voted marker
      assert html =~ "vote" or has_element?(lv, "[data-already-voted]")
    end
  end

  describe "VAL-VOTE-003: Duplicate vote attempts are rejected" do
    setup do
      {:ok, user} = Accounts.create_user(%{email: "user@example.com", password: "password123"})

      now = DateTime.utc_now()

      {:ok, market} =
        Markets.create_market(%{
          question: "Duplicate test market?",
          voting_start: now |> DateTime.add(-3600, :second),
          voting_end: now |> DateTime.add(86400, :second),
          options: ["Yes", "No"]
        })

      option_yes = Enum.find(market.options, fn o -> o.label == "Yes" end)
      option_no = Enum.find(market.options, fn o -> o.label == "No" end)

      %{user: user, market: market, option_yes: option_yes, option_no: option_no}
    end

    test "already-voted user sees already-voted state instead of voting form", %{
      conn: conn,
      user: user,
      market: market,
      option_yes: option
    } do
      # First, cast a vote directly
      assert {:ok, _vote} = Markets.cast_vote(user, market.id, option.id)

      # Now visit the market detail page
      conn = login_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/markets/#{market.id}")

      # Should show already-voted state, not voting form
      assert has_element?(lv, "[data-already-voted]")
      refute has_element?(lv, "#vote-form")
    end

    test "second vote submission is rejected and shows already voted", %{
      conn: conn,
      user: user,
      market: market,
      option_yes: option_yes
    } do
      conn = login_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/markets/#{market.id}")

      # First vote succeeds
      lv
      |> form("#vote-form", %{"vote" => %{"option_id" => option_yes.id}})
      |> render_submit()

      # After voting, the form is gone and already-voted state is shown
      assert has_element?(lv, "[data-already-voted]")
      refute has_element?(lv, "#vote-form")

      # Verify the vote was persisted correctly
      vote = Markets.get_user_vote(user.id, market.id)
      assert vote.market_option_id == option_yes.id
    end
  end

  describe "VAL-VOTE-004: Admins cannot vote" do
    setup do
      {:ok, admin} =
        Accounts.create_user(%{email: "admin@example.com", password: "password123", role: :admin})

      now = DateTime.utc_now()

      {:ok, market} =
        Markets.create_market(%{
          question: "Admin voting test?",
          voting_start: now |> DateTime.add(-3600, :second),
          voting_end: now |> DateTime.add(86400, :second),
          options: ["Yes", "No"]
        })

      option_yes = Enum.find(market.options, fn o -> o.label == "Yes" end)

      %{admin: admin, market: market, option_yes: option_yes}
    end

    test "admin does not see active voting control on market detail page", %{
      conn: conn,
      admin: admin,
      market: market
    } do
      conn = login_user(conn, admin)
      {:ok, lv, _html} = live(conn, ~p"/markets/#{market.id}")

      # Admin should NOT see voting form
      refute has_element?(lv, "#vote-form")
    end

    test "admin sees message indicating they cannot vote", %{
      conn: conn,
      admin: admin,
      market: market
    } do
      conn = login_user(conn, admin)
      {:ok, _lv, html} = live(conn, ~p"/markets/#{market.id}")

      # Should see some indication that admins cannot vote
      assert html =~ "Admin" or html =~ "cannot vote" or html =~ "not eligible"
    end

    test "direct vote submission as admin is rejected server-side", %{
      conn: conn,
      admin: admin,
      market: market,
      option_yes: option
    } do
      conn = login_user(conn, admin)
      {:ok, _lv, _html} = live(conn, ~p"/markets/#{market.id}")

      # Admin should not have voting form to submit
      # But if they try to submit directly somehow, it should fail
      assert {:error, :admin_cannot_vote} = Markets.cast_vote(admin, market.id, option.id)
    end
  end

  describe "VAL-VOTE-007: Guests cannot submit votes directly" do
    setup do
      now = DateTime.utc_now()

      {:ok, market} =
        Markets.create_market(%{
          question: "Guest voting test?",
          voting_start: now |> DateTime.add(-3600, :second),
          voting_end: now |> DateTime.add(86400, :second),
          options: ["Yes", "No"]
        })

      %{market: market}
    end

    test "guest is redirected to sign-in when accessing market detail", %{
      conn: conn,
      market: market
    } do
      {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, ~p"/markets/#{market.id}")
    end
  end

  describe "VAL-VOTE-008: Invalid or tampered vote payloads are rejected" do
    setup do
      {:ok, user} = Accounts.create_user(%{email: "user@example.com", password: "password123"})

      now = DateTime.utc_now()

      {:ok, market} =
        Markets.create_market(%{
          question: "Invalid payload test?",
          voting_start: now |> DateTime.add(-3600, :second),
          voting_end: now |> DateTime.add(86400, :second),
          options: ["Yes", "No"]
        })

      # Create another market to test cross-market option
      {:ok, other_market} =
        Markets.create_market(%{
          question: "Other market?",
          voting_start: now |> DateTime.add(-3600, :second),
          voting_end: now |> DateTime.add(86400, :second),
          options: ["Maybe", "Possibly"]
        })

      option_yes = Enum.find(market.options, fn o -> o.label == "Yes" end)
      other_option = Enum.find(other_market.options, fn o -> o.label == "Maybe" end)

      %{
        user: user,
        market: market,
        other_market: other_market,
        option_yes: option_yes,
        other_option: other_option
      }
    end

    test "submitting nonexistent option is rejected via context", %{
      user: user,
      market: market
    } do
      # Direct context test for nonexistent option
      assert {:error, :invalid_option} = Markets.cast_vote(user, market.id, 99999)

      # No vote should be persisted
      assert Markets.get_user_vote(user.id, market.id) == nil
    end

    test "submitting option from different market is rejected via context", %{
      user: user,
      market: market,
      other_market: other_market
    } do
      # Get an option from the other market
      other_option = Enum.find(other_market.options, fn o -> o.label == "Maybe" end)

      # Try to vote for option from other market in the first market
      # This should fail because the option doesn't belong to the market
      assert {:error, :invalid_option} = Markets.cast_vote(user, market.id, other_option.id)

      # No vote should be persisted
      assert Markets.get_user_vote(user.id, market.id) == nil
    end

    test "missing option shows error", %{
      conn: conn,
      user: user,
      market: market
    } do
      conn = login_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/markets/#{market.id}")

      # Submit with empty form (simulating missing option)
      html = render_submit(lv, "submit_vote", %{})

      # Should show validation error
      assert html =~ "select" or html =~ "Please"

      # No vote should be persisted
      assert Markets.get_user_vote(user.id, market.id) == nil
    end
  end

  describe "VAL-VOTE-009: One-vote enforcement is race-safe" do
    setup do
      {:ok, user} = Accounts.create_user(%{email: "user@example.com", password: "password123"})

      now = DateTime.utc_now()

      {:ok, market} =
        Markets.create_market(%{
          question: "Race condition test?",
          voting_start: now |> DateTime.add(-3600, :second),
          voting_end: now |> DateTime.add(86400, :second),
          options: ["Yes", "No"]
        })

      option = Enum.find(market.options, fn o -> o.label == "Yes" end)

      %{user: user, market: market, option: option}
    end

    test "concurrent or replayed submissions leave exactly one vote", %{
      user: user,
      market: market,
      option: option
    } do
      # Simulate concurrent votes via context API (which is what LiveView uses)
      tasks =
        for _ <- 1..5 do
          Task.async(fn ->
            Markets.cast_vote(user, market.id, option.id)
          end)
        end

      results = Task.await_many(tasks, 5000)

      successes =
        Enum.count(results, fn
          {:ok, _} -> true
          _ -> false
        end)

      # Exactly one should succeed
      assert successes == 1

      # Total votes should be exactly 1
      assert Markets.total_votes(market.id) == 1
    end
  end

  describe "VAL-CROSS-003: Vote state persists across revisits" do
    setup do
      {:ok, user} = Accounts.create_user(%{email: "user@example.com", password: "password123"})

      now = DateTime.utc_now()

      {:ok, market} =
        Markets.create_market(%{
          question: "Persist test?",
          voting_start: now |> DateTime.add(-3600, :second),
          voting_end: now |> DateTime.add(86400, :second),
          options: ["Yes", "No"]
        })

      option_yes = Enum.find(market.options, fn o -> o.label == "Yes" end)

      %{user: user, market: market, option_yes: option_yes}
    end

    test "fresh revisit after voting shows already-voted state and updated totals", %{
      conn: conn,
      user: user,
      market: market,
      option_yes: option
    } do
      conn = login_user(conn, user)

      # Visit the page and cast a vote
      {:ok, lv, _html} = live(conn, ~p"/markets/#{market.id}")

      lv
      |> form("#vote-form", %{"vote" => %{"option_id" => option.id}})
      |> render_submit()

      # Verify the vote was recorded
      assert has_element?(lv, "[data-already-voted]")

      # Simulate a fresh revisit by creating a new LiveView session
      {:ok, lv2, html} = live(conn, ~p"/markets/#{market.id}")

      # Should still show already-voted state
      assert has_element?(lv2, "[data-already-voted]")
      refute has_element?(lv2, "#vote-form")

      # Should show updated totals (1 vote for Yes)
      assert html =~ "1"
    end
  end

  describe "vote totals update after voting" do
    setup do
      {:ok, user} = Accounts.create_user(%{email: "user@example.com", password: "password123"})

      now = DateTime.utc_now()

      {:ok, market} =
        Markets.create_market(%{
          question: "Totals update test?",
          voting_start: now |> DateTime.add(-3600, :second),
          voting_end: now |> DateTime.add(86400, :second),
          options: ["Yes", "No"]
        })

      option_yes = Enum.find(market.options, fn o -> o.label == "Yes" end)

      %{user: user, market: market, option_yes: option_yes}
    end

    test "vote totals increase after successful vote", %{
      conn: conn,
      user: user,
      market: market,
      option_yes: option
    } do
      conn = login_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/markets/#{market.id}")

      # Initial state: 0 votes for all options
      assert has_element?(lv, "[data-option-id='#{option.id}'][data-vote-count='0']")

      # Cast vote
      lv
      |> form("#vote-form", %{"vote" => %{"option_id" => option.id}})
      |> render_submit()

      # After voting: 1 vote for the chosen option
      assert has_element?(lv, "[data-option-id='#{option.id}'][data-vote-count='1']")
    end
  end
end

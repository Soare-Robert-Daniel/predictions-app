defmodule PredictionsWeb.ResolvedMarketStateTest do
  @moduledoc """
  Tests for VAL-RESOLVE-001 through VAL-RESOLVE-006 and VAL-CROSS-006.

  These tests verify that:
  - Markets stay unresolved before the close time (VAL-RESOLVE-001)
  - Resolved markets show majority, tie, or no-vote outcomes explicitly (VAL-RESOLVE-002, VAL-RESOLVE-003, VAL-RESOLVE-004)
  - Resolved markets no longer expose an actionable voting path (VAL-RESOLVE-005)
  - Resolved state is stable across repeated reads (VAL-RESOLVE-006)
  - List and detail pages agree on market state (VAL-CROSS-006)
  """

  use PredictionsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Predictions.Accounts
  alias Predictions.Markets
  alias Predictions.Markets.Vote
  alias Predictions.Repo

  describe "VAL-RESOLVE-001: Market remains unresolved before voting ends" do
    setup do
      {:ok, user} = Accounts.create_user(%{email: "user@example.com", password: "password123"})
      now = DateTime.utc_now()

      # Create an active market (voting is currently open)
      {:ok, active_market} =
        Markets.create_market(%{
          question: "Active market?",
          voting_start: now |> DateTime.add(-3600, :second),
          voting_end: now |> DateTime.add(86400, :second),
          options: ["Yes", "No", "Maybe"]
        })

      %{user: user, active_market: active_market}
    end

    test "active market appears as active, not resolved", %{
      conn: conn,
      user: user,
      active_market: market
    } do
      conn = login_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/markets/#{market.id}")

      # Should show active state marker, NOT resolved
      assert has_element?(lv, "[data-market-state='active']")
      refute has_element?(lv, "[data-market-state='resolved']")

      # Should NOT show outcome section
      refute has_element?(lv, "[data-resolved-outcome]")
    end

    test "active market shows voting form for eligible user", %{
      conn: conn,
      user: user,
      active_market: market
    } do
      conn = login_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/markets/#{market.id}")

      # Should show voting form (actionable voting path)
      assert has_element?(lv, "#vote-form")
    end

    test "market list shows active state for active market", %{
      conn: conn,
      user: user,
      active_market: _market
    } do
      conn = login_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/markets")

      assert has_element?(lv, "[data-market-state='active']")
      refute has_element?(lv, "[data-market-state='resolved']")
    end
  end

  describe "VAL-RESOLVE-002: Majority winner is shown after the voting period ends" do
    setup do
      {:ok, user} = Accounts.create_user(%{email: "user@example.com", password: "password123"})

      {:ok, voter1} =
        Accounts.create_user(%{email: "voter1@example.com", password: "password123"})

      {:ok, voter2} =
        Accounts.create_user(%{email: "voter2@example.com", password: "password123"})

      {:ok, voter3} =
        Accounts.create_user(%{email: "voter3@example.com", password: "password123"})

      now = DateTime.utc_now()

      {:ok, market} =
        Markets.create_market(%{
          question: "Majority winner test?",
          voting_start: now |> DateTime.add(-86400, :second),
          voting_end: now |> DateTime.add(-3600, :second),
          options: ["Yes", "No", "Maybe"]
        })

      option_yes = Enum.find(market.options, fn o -> o.label == "Yes" end)
      option_no = Enum.find(market.options, fn o -> o.label == "No" end)

      # Insert votes directly (market is closed)
      Repo.insert!(%Vote{
        user_id: voter1.id,
        market_id: market.id,
        market_option_id: option_yes.id
      })

      Repo.insert!(%Vote{
        user_id: voter2.id,
        market_id: market.id,
        market_option_id: option_yes.id
      })

      Repo.insert!(%Vote{
        user_id: voter3.id,
        market_id: market.id,
        market_option_id: option_no.id
      })

      # Resolve the market
      {:ok, resolved_market} = Markets.resolve_market(market)

      %{
        user: user,
        market: resolved_market,
        winning_option: option_yes
      }
    end

    test "resolved market shows majority winner explicitly", %{
      conn: conn,
      user: user,
      market: market,
      winning_option: winning_option
    } do
      conn = login_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/markets/#{market.id}")

      # Should show resolved state marker
      assert html =~ "data-market-state=\"resolved\""

      # Should show majority outcome explicitly
      assert html =~ "data-outcome=\"majority\""

      # Should show winning option label
      assert html =~ winning_option.label

      # Should show "Winner" or "Winning option" marker
      assert html =~ "Winner" or html =~ "winning" or html =~ "Outcome"
    end

    test "resolved market detail shows resolved outcome section", %{
      conn: conn,
      user: user,
      market: market
    } do
      conn = login_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/markets/#{market.id}")

      assert has_element?(lv, "[data-resolved-outcome]")
    end

    test "majority winner is shown in market list for resolved markets", %{
      conn: conn,
      user: user,
      market: _market,
      winning_option: winning_option
    } do
      conn = login_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/markets")

      # Should show resolved state in list
      assert html =~ "data-market-state=\"resolved\""

      # Should show outcome indicator
      assert html =~ "Resolved" or html =~ winning_option.label
    end
  end

  describe "VAL-RESOLVE-003: Tie outcomes are explicit" do
    setup do
      {:ok, user} = Accounts.create_user(%{email: "user@example.com", password: "password123"})

      {:ok, voter1} =
        Accounts.create_user(%{email: "voter1@example.com", password: "password123"})

      {:ok, voter2} =
        Accounts.create_user(%{email: "voter2@example.com", password: "password123"})

      now = DateTime.utc_now()

      {:ok, market} =
        Markets.create_market(%{
          question: "Tie outcome test?",
          voting_start: now |> DateTime.add(-86400, :second),
          voting_end: now |> DateTime.add(-3600, :second),
          options: ["Yes", "No"]
        })

      option_yes = Enum.find(market.options, fn o -> o.label == "Yes" end)
      option_no = Enum.find(market.options, fn o -> o.label == "No" end)

      # Equal votes - tie
      Repo.insert!(%Vote{
        user_id: voter1.id,
        market_id: market.id,
        market_option_id: option_yes.id
      })

      Repo.insert!(%Vote{
        user_id: voter2.id,
        market_id: market.id,
        market_option_id: option_no.id
      })

      # Resolve the market
      {:ok, resolved_market} = Markets.resolve_market(market)

      %{user: user, market: resolved_market}
    end

    test "tie outcome shows explicit tie state", %{conn: conn, user: user, market: market} do
      conn = login_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/markets/#{market.id}")

      # Should show resolved state marker
      assert html =~ "data-market-state=\"resolved\""

      # Should show tie outcome explicitly
      assert html =~ "data-outcome=\"tie\""

      # Should show "Tie" or "No winner" message
      assert html =~ "Tie" or html =~ "no winner" or html =~ "tied"

      # Should NOT show a single winner
      refute html =~ "Winner:" and html =~ "Winning option:"
    end

    test "tie outcome shows no single winner marker", %{conn: conn, user: user, market: market} do
      conn = login_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/markets/#{market.id}")

      # Should have tie outcome marker
      assert has_element?(lv, "[data-outcome='tie']")

      # Should NOT have majority winner marker
      refute has_element?(lv, "[data-outcome='majority']")
    end

    test "tie outcome is consistent in market list", %{conn: conn, user: user, market: _market} do
      conn = login_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/markets")

      # Should show resolved state
      assert html =~ "data-market-state=\"resolved\""

      # Should indicate tie outcome
      assert html =~ "Tie" or html =~ "tied"
    end
  end

  describe "VAL-RESOLVE-004: No-vote markets resolve explicitly" do
    setup do
      {:ok, user} = Accounts.create_user(%{email: "user@example.com", password: "password123"})

      now = DateTime.utc_now()

      {:ok, market} =
        Markets.create_market(%{
          question: "No votes test?",
          voting_start: now |> DateTime.add(-86400, :second),
          voting_end: now |> DateTime.add(-3600, :second),
          options: ["Yes", "No"]
        })

      # No votes cast - resolve with no_votes outcome
      {:ok, resolved_market} = Markets.resolve_market(market)

      %{user: user, market: resolved_market}
    end

    test "no-vote outcome shows explicit no-votes state", %{
      conn: conn,
      user: user,
      market: market
    } do
      conn = login_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/markets/#{market.id}")

      # Should show resolved state marker
      assert html =~ "data-market-state=\"resolved\""

      # Should show no_votes outcome explicitly
      assert html =~ "data-outcome=\"no_votes\""

      # Should show "No votes" or "No outcome" message
      assert html =~ "No votes" or html =~ "no votes" or html =~ "No outcome"

      # Should NOT show a winner
      refute html =~ "Winner:"
    end

    test "no-vote outcome shows no winner marker", %{conn: conn, user: user, market: market} do
      conn = login_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/markets/#{market.id}")

      # Should have no_votes outcome marker
      assert has_element?(lv, "[data-outcome='no_votes']")

      # Should NOT have majority winner marker
      refute has_element?(lv, "[data-outcome='majority']")
    end

    test "no-vote outcome is consistent in market list", %{
      conn: conn,
      user: user,
      market: _market
    } do
      conn = login_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/markets")

      # Should show resolved state
      assert html =~ "data-market-state=\"resolved\""

      # Should indicate no votes or no outcome
      assert html =~ "No votes" or html =~ "no outcome"
    end
  end

  describe "VAL-RESOLVE-005: Resolved markets no longer allow voting" do
    setup do
      {:ok, user} = Accounts.create_user(%{email: "user@example.com", password: "password123"})
      {:ok, voter} = Accounts.create_user(%{email: "voter@example.com", password: "password123"})

      now = DateTime.utc_now()

      {:ok, market} =
        Markets.create_market(%{
          question: "Resolved voting test?",
          voting_start: now |> DateTime.add(-86400, :second),
          voting_end: now |> DateTime.add(-3600, :second),
          options: ["Yes", "No"]
        })

      option = Enum.find(market.options, fn o -> o.label == "Yes" end)
      Repo.insert!(%Vote{user_id: voter.id, market_id: market.id, market_option_id: option.id})

      {:ok, resolved_market} = Markets.resolve_market(market)

      %{user: user, market: resolved_market}
    end

    test "resolved market does not show voting form", %{conn: conn, user: user, market: market} do
      conn = login_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/markets/#{market.id}")

      # Should NOT show voting form
      refute has_element?(lv, "#vote-form")

      # Should show that voting is unavailable
      assert has_element?(lv, "[data-voting-unavailable]")
    end

    test "resolved market shows final results instead of voting flow", %{
      conn: conn,
      user: user,
      market: market
    } do
      conn = login_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/markets/#{market.id}")

      # Should show final outcome section
      assert html =~ "data-resolved-outcome"

      # Should show "Market Resolved" or similar
      assert html =~ "Resolved" or html =~ "final"
    end

    test "post-resolution vote submission is rejected server-side", %{
      user: user,
      market: market
    } do
      option = Enum.find(market.options, fn _o -> true end)

      # Market is already resolved, voting should be rejected
      assert {:error, :market_inactive} = Markets.cast_vote(user, market.id, option.id)

      # Vote count should be unchanged
      assert Markets.total_votes(market.id) == 1
    end
  end

  describe "VAL-RESOLVE-006: Resolution is persisted and idempotent" do
    setup do
      {:ok, user} = Accounts.create_user(%{email: "user@example.com", password: "password123"})
      {:ok, voter} = Accounts.create_user(%{email: "voter@example.com", password: "password123"})

      now = DateTime.utc_now()

      {:ok, market} =
        Markets.create_market(%{
          question: "Idempotent test?",
          voting_start: now |> DateTime.add(-86400, :second),
          voting_end: now |> DateTime.add(-3600, :second),
          options: ["Yes", "No"]
        })

      option = Enum.find(market.options, fn o -> o.label == "Yes" end)
      Repo.insert!(%Vote{user_id: voter.id, market_id: market.id, market_option_id: option.id})

      {:ok, resolved_market} = Markets.resolve_market(market)

      %{user: user, market: resolved_market, winning_option: option}
    end

    test "resolved status is stable across repeated reads", %{
      conn: conn,
      user: user,
      market: market,
      winning_option: winning_option
    } do
      conn = login_user(conn, user)

      # First read
      {:ok, _lv, html1} = live(conn, ~p"/markets/#{market.id}")

      # Second read
      {:ok, _lv, html2} = live(conn, ~p"/markets/#{market.id}")

      # Both should show the same outcome
      assert html1 =~ "data-market-state=\"resolved\""
      assert html2 =~ "data-market-state=\"resolved\""

      assert html1 =~ "data-outcome=\"majority\""
      assert html2 =~ "data-outcome=\"majority\""

      assert html1 =~ winning_option.label
      assert html2 =~ winning_option.label
    end

    test "repeated resolution checks do not change outcome", %{market: market} do
      # Try to resolve again
      assert {:error, :already_resolved} = Markets.resolve_market(market)

      # Outcome should be unchanged
      fetched = Markets.get_market!(market.id)
      assert fetched.outcome == market.outcome
      assert fetched.winning_option_id == market.winning_option_id
      assert fetched.resolved_at == market.resolved_at
    end
  end

  describe "VAL-CROSS-006: Market state is consistent across list and detail views" do
    setup do
      {:ok, user} = Accounts.create_user(%{email: "user@example.com", password: "password123"})

      now = DateTime.utc_now()

      # Create markets in different states
      {:ok, upcoming_market} =
        Markets.create_market(%{
          question: "Upcoming market?",
          voting_start: now |> DateTime.add(3600, :second),
          voting_end: now |> DateTime.add(86400, :second),
          options: ["Yes", "No"]
        })

      {:ok, active_market} =
        Markets.create_market(%{
          question: "Active market?",
          voting_start: now |> DateTime.add(-3600, :second),
          voting_end: now |> DateTime.add(86400, :second),
          options: ["Yes", "No"]
        })

      {:ok, closed_market} =
        Markets.create_market(%{
          question: "Closed market?",
          voting_start: now |> DateTime.add(-86400, :second),
          voting_end: now |> DateTime.add(-3600, :second),
          options: ["Yes", "No"]
        })

      {:ok, resolved_market} = Markets.resolve_market(closed_market)

      %{
        user: user,
        upcoming_market: upcoming_market,
        active_market: active_market,
        resolved_market: resolved_market
      }
    end

    test "upcoming market shows consistent state in list and detail", %{
      conn: conn,
      user: user,
      upcoming_market: market
    } do
      conn = login_user(conn, user)

      # Check list view
      {:ok, list_lv, _html} = live(conn, ~p"/markets")
      assert has_element?(list_lv, "[data-market-state='upcoming']")

      # Check detail view
      {:ok, detail_lv, _html} = live(conn, ~p"/markets/#{market.id}")
      assert has_element?(detail_lv, "[data-market-state='upcoming']")
    end

    test "active market shows consistent state in list and detail", %{
      conn: conn,
      user: user,
      active_market: market
    } do
      conn = login_user(conn, user)

      # Check list view
      {:ok, list_lv, _html} = live(conn, ~p"/markets")
      assert has_element?(list_lv, "[data-market-state='active']")

      # Check detail view
      {:ok, detail_lv, _html} = live(conn, ~p"/markets/#{market.id}")
      assert has_element?(detail_lv, "[data-market-state='active']")

      # Only active state should show voting form
      assert has_element?(detail_lv, "#vote-form")
    end

    test "resolved market shows consistent state in list and detail", %{
      conn: conn,
      user: user,
      resolved_market: market
    } do
      conn = login_user(conn, user)

      # Check list view
      {:ok, list_lv, _html} = live(conn, ~p"/markets")
      assert has_element?(list_lv, "[data-market-state='resolved']")

      # Check detail view
      {:ok, detail_lv, _html} = live(conn, ~p"/markets/#{market.id}")
      assert has_element?(detail_lv, "[data-market-state='resolved']")

      # Resolved state should NOT show voting form
      refute has_element?(detail_lv, "#vote-form")

      # Should show outcome
      assert has_element?(detail_lv, "[data-resolved-outcome]")
    end

    test "only active state exposes actionable voting path", %{
      conn: conn,
      user: user,
      upcoming_market: upcoming,
      active_market: active,
      resolved_market: resolved
    } do
      conn = login_user(conn, user)

      # Upcoming - no voting
      {:ok, upcoming_lv, _html} = live(conn, ~p"/markets/#{upcoming.id}")
      refute has_element?(upcoming_lv, "#vote-form")

      # Active - voting available
      {:ok, active_lv, _html} = live(conn, ~p"/markets/#{active.id}")
      assert has_element?(active_lv, "#vote-form")

      # Resolved - no voting
      {:ok, resolved_lv, _html} = live(conn, ~p"/markets/#{resolved.id}")
      refute has_element?(resolved_lv, "#vote-form")
    end
  end
end

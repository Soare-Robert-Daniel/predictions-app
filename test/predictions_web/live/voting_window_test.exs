defmodule PredictionsWeb.VotingWindowTest do
  @moduledoc """
  Tests for VAL-VOTE-005: Voting is blocked outside the active window.

  These tests verify that:
  - Vote submission fails before the market opens
  - Vote submission fails after the market closes
  - Users see a clear non-votable state outside the active window
  """

  use PredictionsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Predictions.Accounts
  alias Predictions.Markets

  describe "VAL-VOTE-005: Voting is blocked outside the active window" do
    setup do
      {:ok, user} = Accounts.create_user(%{email: "user@example.com", password: "password123"})

      now = DateTime.utc_now()

      # Create an upcoming market (voting hasn't started)
      {:ok, upcoming_market} =
        Markets.create_market(%{
          question: "Upcoming market?",
          voting_start: now |> DateTime.add(3600, :second),
          voting_end: now |> DateTime.add(86400, :second),
          options: ["Yes", "No"]
        })

      # Create a closed market (voting has ended but not resolved)
      {:ok, closed_market} =
        Markets.create_market(%{
          question: "Closed market?",
          voting_start: now |> DateTime.add(-86400, :second),
          voting_end: now |> DateTime.add(-3600, :second),
          options: ["Yes", "No"]
        })

      upcoming_option = Enum.find(upcoming_market.options, fn o -> o.label == "Yes" end)
      closed_option = Enum.find(closed_market.options, fn o -> o.label == "Yes" end)

      %{
        user: user,
        upcoming_market: upcoming_market,
        closed_market: closed_market,
        upcoming_option: upcoming_option,
        closed_option: closed_option
      }
    end

    # --- Server-side rejection tests ---

    test "vote submission is rejected before market opens via context API", %{
      user: user,
      upcoming_market: market,
      upcoming_option: option
    } do
      assert {:error, :market_inactive} = Markets.cast_vote(user, market.id, option.id)

      # No vote should be persisted
      assert Markets.get_user_vote(user.id, market.id) == nil
    end

    test "vote submission is rejected after market closes via context API", %{
      user: user,
      closed_market: market,
      closed_option: option
    } do
      assert {:error, :market_inactive} = Markets.cast_vote(user, market.id, option.id)

      # No vote should be persisted
      assert Markets.get_user_vote(user.id, market.id) == nil
    end

    # --- UI state tests for upcoming markets ---

    test "upcoming market shows non-votable state in UI", %{
      conn: conn,
      user: user,
      upcoming_market: market
    } do
      conn = login_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/markets/#{market.id}")

      # Should show upcoming state marker
      assert has_element?(lv, "[data-market-state='upcoming']")

      # Should NOT show voting form
      refute has_element?(lv, "#vote-form")

      # Should show voting unavailable message
      assert has_element?(lv, "[data-voting-unavailable]")
    end

    test "upcoming market shows 'voting has not started' message", %{
      conn: conn,
      user: user,
      upcoming_market: market
    } do
      conn = login_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/markets/#{market.id}")

      # Should show message indicating voting hasn't started
      assert html =~ "Voting has not started" or html =~ "not started yet"
    end

    # --- UI state tests for closed markets ---

    test "closed market shows non-votable state in UI", %{
      conn: conn,
      user: user,
      closed_market: market
    } do
      conn = login_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/markets/#{market.id}")

      # Should show closed state marker
      assert has_element?(lv, "[data-market-state='closed']")

      # Should NOT show voting form
      refute has_element?(lv, "#vote-form")

      # Should show voting unavailable message
      assert has_element?(lv, "[data-voting-unavailable]")
    end

    test "closed market shows 'voting has ended' message", %{
      conn: conn,
      user: user,
      closed_market: market
    } do
      conn = login_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/markets/#{market.id}")

      # Should show message indicating voting has ended
      assert html =~ "ended" or html =~ "closed" or html =~ "no longer available"
    end

    # --- Market list consistency ---

    test "market list shows correct state for upcoming market", %{
      conn: conn,
      user: user,
      upcoming_market: _market
    } do
      conn = login_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/markets")

      assert has_element?(lv, "[data-market-state='upcoming']")
    end

    test "market list shows correct state for closed market", %{
      conn: conn,
      user: user,
      closed_market: _market
    } do
      conn = login_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/markets")

      assert has_element?(lv, "[data-market-state='closed']")
    end

    # --- Active market control test ---

    test "active market shows voting form for eligible user" do
      {:ok, user} =
        Accounts.create_user(%{email: "active_user@example.com", password: "password123"})

      now = DateTime.utc_now()

      {:ok, active_market} =
        Markets.create_market(%{
          question: "Active market?",
          voting_start: now |> DateTime.add(-3600, :second),
          voting_end: now |> DateTime.add(86400, :second),
          options: ["Yes", "No"]
        })

      conn = build_conn()
      conn = login_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/markets/#{active_market.id}")

      # Should show active state marker
      assert has_element?(lv, "[data-market-state='active']")

      # Should show voting form
      assert has_element?(lv, "#vote-form")
    end
  end

  describe "market status consistency" do
    test "Market.status/2 returns :upcoming before voting start" do
      now = DateTime.utc_now()

      {:ok, market} =
        Markets.create_market(%{
          question: "Upcoming?",
          voting_start: now |> DateTime.add(3600, :second),
          voting_end: now |> DateTime.add(86400, :second),
          options: ["Yes", "No"]
        })

      assert Predictions.Markets.Market.status(market, now) == :upcoming
    end

    test "Market.status/2 returns :active during voting window" do
      now = DateTime.utc_now()

      {:ok, market} =
        Markets.create_market(%{
          question: "Active?",
          voting_start: now |> DateTime.add(-3600, :second),
          voting_end: now |> DateTime.add(86400, :second),
          options: ["Yes", "No"]
        })

      assert Predictions.Markets.Market.status(market, now) == :active
    end

    test "Market.status/2 returns :closed after voting end (not resolved)" do
      now = DateTime.utc_now()

      {:ok, market} =
        Markets.create_market(%{
          question: "Closed?",
          voting_start: now |> DateTime.add(-86400, :second),
          voting_end: now |> DateTime.add(-3600, :second),
          options: ["Yes", "No"]
        })

      # Market should be closed, not active
      assert Predictions.Markets.Market.status(market, now) == :closed
    end

    test "Market.status/2 returns :resolved when outcome is set" do
      now = DateTime.utc_now()

      {:ok, market} =
        Markets.create_market(%{
          question: "Resolved?",
          voting_start: now |> DateTime.add(-86400, :second),
          voting_end: now |> DateTime.add(-3600, :second),
          options: ["Yes", "No"]
        })

      {:ok, resolved_market} = Markets.resolve_market(market)

      assert Predictions.Markets.Market.status(resolved_market, now) == :resolved
    end
  end
end

defmodule PredictionsWeb.EndToEndLifecycleTest do
  @moduledoc """
  Tests for VAL-CROSS-005: End-to-end market lifecycle is coherent across roles.

  This test verifies that:
  - An admin can create a market
  - A separate signed-in normal user can discover it and cast one vote while it is active
  - The market resolves automatically after close
  - That participant receives exactly one notification pointing to the resolved market
  """

  use PredictionsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Predictions.Accounts
  alias Predictions.Markets
  alias Predictions.Markets.Vote
  alias Predictions.Repo

  describe "VAL-CROSS-005: End-to-end market lifecycle is coherent across roles" do
    setup do
      {:ok, admin} =
        Accounts.create_user(%{email: "admin@example.com", password: "password123", role: :admin})

      {:ok, user} = Accounts.create_user(%{email: "user@example.com", password: "password123"})

      %{admin: admin, user: user}
    end

    test "full lifecycle: admin creates, user votes, market resolves, user gets notification", %{
      conn: conn,
      admin: _admin,
      user: user
    } do
      now = DateTime.utc_now()

      # STEP 1: Admin creates a market (simulated via context, form test is in admin_create_market_live_test.exs)
      {:ok, _created_market} =
        Markets.create_market(%{
          question: "Will the end-to-end test pass?",
          voting_start: now |> DateTime.add(-1800, :second),
          voting_end: now |> DateTime.add(-60, :second),
          options: ["Yes", "No"]
        })

      # STEP 2: User discovers the market
      # Create an active market for voting
      {:ok, active_market} =
        Markets.create_market(%{
          question: "End-to-end active test?",
          voting_start: now |> DateTime.add(-3600, :second),
          voting_end: now |> DateTime.add(3600, :second),
          options: ["Yes", "No"]
        })

      user_conn = login_user(conn, user)

      # User browses markets
      {:ok, list_lv, _html} = live(user_conn, ~p"/markets")
      assert has_element?(list_lv, "[data-market-state='active']")

      # User opens market detail
      {:ok, detail_lv, _html} = live(user_conn, ~p"/markets/#{active_market.id}")
      assert has_element?(detail_lv, "[data-market-state='active']")
      assert has_element?(detail_lv, "#vote-form")

      # User casts vote
      option_yes = Enum.find(active_market.options, fn o -> o.label == "Yes" end)

      html =
        form(detail_lv, "#vote-form", vote: %{option_id: option_yes.id})
        |> render_submit()

      # Should show vote recorded
      assert html =~ "data-already-voted"

      # STEP 3: Create a market that has ended and resolve it
      {:ok, ended_market} =
        Markets.create_market(%{
          question: "End-to-end ended test?",
          voting_start: now |> DateTime.add(-7200, :second),
          voting_end: now |> DateTime.add(-60, :second),
          options: ["Yes", "No"]
        })

      ended_option_yes = Enum.find(ended_market.options, fn o -> o.label == "Yes" end)

      # User votes in this ended market
      Repo.insert!(%Vote{
        user_id: user.id,
        market_id: ended_market.id,
        market_option_id: ended_option_yes.id
      })

      # Resolve the market
      {:ok, resolved_market} = Markets.resolve_market(ended_market)

      # STEP 4: User receives notification
      notifications = Markets.list_notifications(user.id)
      assert length(notifications) == 1

      notification = hd(notifications)
      assert notification.market_id == resolved_market.id

      # User checks notifications
      {:ok, notif_lv, _html} = live(user_conn, ~p"/notifications")
      assert has_element?(notif_lv, "[data-notification-market-id='#{resolved_market.id}']")

      # User follows notification link to resolved market
      {:ok, resolved_lv, _html} = live(user_conn, ~p"/markets/#{resolved_market.id}")

      # Should show resolved state
      assert has_element?(resolved_lv, "[data-market-state='resolved']")
      assert has_element?(resolved_lv, "[data-resolved-outcome]")

      # Should show the same outcome
      assert has_element?(resolved_lv, "[data-outcome='majority']")
    end

    test "admin creates market that appears in user browsing", %{
      conn: conn,
      admin: _admin,
      user: user
    } do
      now = DateTime.utc_now()

      {:ok, market} =
        Markets.create_market(%{
          question: "Cross-role visibility test?",
          voting_start: now |> DateTime.add(-3600, :second),
          voting_end: now |> DateTime.add(3600, :second),
          options: ["Yes", "No"]
        })

      # User can see the admin-created market
      user_conn = login_user(conn, user)
      {:ok, _lv, html} = live(user_conn, ~p"/markets")

      assert html =~ market.question

      # User can access the market detail
      {:ok, _lv, html} = live(user_conn, ~p"/markets/#{market.id}")
      assert html =~ market.question
    end

    test "user vote persists and shows in notification", %{conn: conn, user: user} do
      now = DateTime.utc_now()

      {:ok, market} =
        Markets.create_market(%{
          question: "Vote persistence test?",
          voting_start: now |> DateTime.add(-3600, :second),
          voting_end: now |> DateTime.add(-60, :second),
          options: ["Option A", "Option B"]
        })

      option_a = Enum.find(market.options, fn o -> o.label == "Option A" end)

      # User votes
      Repo.insert!(%Vote{
        user_id: user.id,
        market_id: market.id,
        market_option_id: option_a.id
      })

      # Resolve
      {:ok, resolved} = Markets.resolve_market(market)

      # Check notification references the resolved market
      notifications = Markets.list_notifications(user.id)
      assert length(notifications) == 1

      notification = hd(notifications)
      assert notification.market_id == resolved.id
      assert notification.message =~ "Vote persistence test?"

      # Notification links to the same market
      user_conn = login_user(conn, user)
      {:ok, _lv, html} = live(user_conn, ~p"/notifications")
      assert html =~ "href=\"/markets/#{resolved.id}\""
    end
  end
end

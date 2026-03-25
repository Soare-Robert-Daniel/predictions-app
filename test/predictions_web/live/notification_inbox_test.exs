defmodule PredictionsWeb.NotificationInboxTest do
  @moduledoc """
  Tests for VAL-NOTIFY-001 through VAL-NOTIFY-004 and VAL-CROSS-004.

  These tests verify that:
  - Participants receive one in-app notification per resolved market (VAL-NOTIFY-001)
  - Non-participants do not receive that notification (VAL-NOTIFY-002)
  - Resolution notifications are not sent before resolution (VAL-NOTIFY-003)
  - Resolution notifications are idempotent (VAL-NOTIFY-004)
  - Notification deep-links open the resolved market page with the same final outcome (VAL-CROSS-004)
  """

  use PredictionsWeb.ConnCase, async: true

  import Ecto.Query
  import Phoenix.LiveViewTest

  alias Predictions.Accounts
  alias Predictions.Markets
  alias Predictions.Markets.Notification
  alias Predictions.Markets.Vote
  alias Predictions.Repo

  describe "VAL-NOTIFY-001: Participants receive one in-app notification when a market resolves" do
    setup do
      {:ok, user} = Accounts.create_user(%{email: "user@example.com", password: "password123"})

      {:ok, voter1} =
        Accounts.create_user(%{email: "voter1@example.com", password: "password123"})

      {:ok, voter2} =
        Accounts.create_user(%{email: "voter2@example.com", password: "password123"})

      now = DateTime.utc_now()

      {:ok, market} =
        Markets.create_market(%{
          question: "Notification test?",
          voting_start: now |> DateTime.add(-86400, :second),
          voting_end: now |> DateTime.add(-3600, :second),
          options: ["Yes", "No", "Maybe"]
        })

      option_yes = Enum.find(market.options, fn o -> o.label == "Yes" end)
      option_no = Enum.find(market.options, fn o -> o.label == "No" end)

      %{
        user: user,
        voter1: voter1,
        voter2: voter2,
        market: market,
        option_yes: option_yes,
        option_no: option_no
      }
    end

    test "each participant receives exactly one notification after resolution", %{
      conn: conn,
      voter1: voter1,
      voter2: voter2,
      market: market,
      option_yes: option_yes,
      option_no: option_no
    } do
      # Voters cast votes
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
      {:ok, _resolved} = Markets.resolve_market(market)

      # Check notifications for voter1
      conn = login_user(conn, voter1)
      {:ok, _lv, html} = live(conn, ~p"/notifications")

      # Should see notification for this market
      assert html =~ "data-notification-market-id=\"#{market.id}\""
      assert html =~ "Notification test?"

      # Count notifications for voter1
      notifications = Markets.list_notifications(voter1.id)
      assert length(notifications) == 1
      assert hd(notifications).market_id == market.id
    end

    test "notification identifies the market and outcome", %{
      conn: conn,
      voter1: voter1,
      market: market,
      option_yes: option_yes
    } do
      # Voter votes for Yes
      Repo.insert!(%Vote{
        user_id: voter1.id,
        market_id: market.id,
        market_option_id: option_yes.id
      })

      # Resolve with majority
      {:ok, _resolved} = Markets.resolve_market(market)

      conn = login_user(conn, voter1)
      {:ok, _lv, html} = live(conn, ~p"/notifications")

      # Should show the market question
      assert html =~ "Notification test?"

      # Should show the outcome (Yes won with 1 vote)
      assert html =~ "Yes"
    end

    test "notification count is visible in user dashboard", %{
      conn: conn,
      voter1: voter1,
      market: market,
      option_yes: option_yes
    } do
      Repo.insert!(%Vote{
        user_id: voter1.id,
        market_id: market.id,
        market_option_id: option_yes.id
      })

      # Before resolution - notification count is 0
      conn = login_user(conn, voter1)
      {:ok, _lv, html} = live(conn, ~p"/dashboard")
      assert html =~ "data-notification-count=\"0\""

      # Resolve
      {:ok, _resolved} = Markets.resolve_market(market)

      # After resolution - notification count appears
      {:ok, _lv, html} = live(conn, ~p"/dashboard")
      assert html =~ "data-notification-count=\"1\""
    end
  end

  describe "VAL-NOTIFY-002: Non-participants do not receive that resolution notification" do
    setup do
      {:ok, voter} = Accounts.create_user(%{email: "voter@example.com", password: "password123"})

      {:ok, non_voter} =
        Accounts.create_user(%{email: "nonvoter@example.com", password: "password123"})

      now = DateTime.utc_now()

      {:ok, market} =
        Markets.create_market(%{
          question: "Non-participant test?",
          voting_start: now |> DateTime.add(-86400, :second),
          voting_end: now |> DateTime.add(-3600, :second),
          options: ["Yes", "No"]
        })

      option_yes = Enum.find(market.options, fn o -> o.label == "Yes" end)

      %{voter: voter, non_voter: non_voter, market: market, option_yes: option_yes}
    end

    test "non-participant does not receive resolution notification", %{
      conn: conn,
      voter: voter,
      non_voter: non_voter,
      market: market,
      option_yes: option_yes
    } do
      # Only voter votes
      Repo.insert!(%Vote{
        user_id: voter.id,
        market_id: market.id,
        market_option_id: option_yes.id
      })

      # Resolve
      {:ok, _resolved} = Markets.resolve_market(market)

      # Check voter's notifications
      notifications = Markets.list_notifications(voter.id)
      assert length(notifications) == 1

      # Check non-participant's notifications
      non_participant_notifications = Markets.list_notifications(non_voter.id)
      assert Enum.empty?(non_participant_notifications)

      # Verify in UI
      conn = login_user(conn, non_voter)
      {:ok, _lv, html} = live(conn, ~p"/notifications")

      # Should show no notifications
      assert html =~ "No notifications" || html =~ "no notifications"
      refute html =~ "Non-participant test?"
    end
  end

  describe "VAL-NOTIFY-003: Resolution notifications are not sent before resolution" do
    setup do
      {:ok, user} = Accounts.create_user(%{email: "user@example.com", password: "password123"})
      now = DateTime.utc_now()

      # Create active market (hasn't ended yet)
      {:ok, active_market} =
        Markets.create_market(%{
          question: "Active market for notification?",
          voting_start: now |> DateTime.add(-3600, :second),
          voting_end: now |> DateTime.add(86400, :second),
          options: ["Yes", "No"]
        })

      option_yes = Enum.find(active_market.options, fn o -> o.label == "Yes" end)

      %{user: user, active_market: active_market, option_yes: option_yes}
    end

    test "participant does not have notification before resolution", %{
      conn: conn,
      user: user,
      active_market: active_market,
      option_yes: option_yes
    } do
      # Vote in active market
      Repo.insert!(%Vote{
        user_id: user.id,
        market_id: active_market.id,
        market_option_id: option_yes.id
      })

      # Before resolution - no notifications
      notifications = Markets.list_notifications(user.id)
      assert Enum.empty?(notifications)

      # Verify in UI
      conn = login_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/notifications")

      # Should show no notifications
      assert html =~ "No notifications" || html =~ "no notifications"
      refute html =~ "Active market for notification?"
    end
  end

  describe "VAL-NOTIFY-004: Resolution notifications are idempotent" do
    setup do
      {:ok, user} = Accounts.create_user(%{email: "user@example.com", password: "password123"})
      now = DateTime.utc_now()

      {:ok, market} =
        Markets.create_market(%{
          question: "Idempotent notification test?",
          voting_start: now |> DateTime.add(-86400, :second),
          voting_end: now |> DateTime.add(-3600, :second),
          options: ["Yes", "No"]
        })

      option_yes = Enum.find(market.options, fn o -> o.label == "Yes" end)

      %{user: user, market: market, option_yes: option_yes}
    end

    test "participant keeps exactly one notification after repeated resolution checks", %{
      conn: conn,
      user: user,
      market: market,
      option_yes: option_yes
    } do
      # Vote
      Repo.insert!(%Vote{
        user_id: user.id,
        market_id: market.id,
        market_option_id: option_yes.id
      })

      # Resolve once
      {:ok, resolved} = Markets.resolve_market(market)

      # Count notifications
      notifications_after_first = Markets.list_notifications(user.id)
      assert length(notifications_after_first) == 1

      # Try to resolve again
      {:error, :already_resolved} = Markets.resolve_market(resolved)

      # Run batch resolution (should be idempotent)
      Markets.resolve_ended_markets()

      # Count should still be 1
      notifications_after_repeated = Markets.list_notifications(user.id)
      assert length(notifications_after_repeated) == 1

      # Verify in UI
      conn = login_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/notifications")

      # Should show exactly one notification
      notification_count =
        (html |> String.split("data-notification-market-id") |> length()) - 1

      assert notification_count == 1
    end

    test "notification count remains one per participant/market even with repeated resolution checks",
         %{user: user, market: market, option_yes: option_yes} do
      Repo.insert!(%Vote{
        user_id: user.id,
        market_id: market.id,
        market_option_id: option_yes.id
      })

      {:ok, _resolved} = Markets.resolve_market(market)

      # Multiple resolution checks
      Markets.resolve_ended_markets()
      Markets.resolve_ended_markets()
      Markets.resolve_ended_markets()

      # Verify single notification in database
      count =
        from(n in Notification,
          where: n.user_id == ^user.id and n.market_id == ^market.id
        )
        |> Repo.aggregate(:count, :id)

      assert count == 1
    end
  end

  describe "VAL-CROSS-004: Notification deep-links open the resolved market state" do
    setup do
      {:ok, user} = Accounts.create_user(%{email: "user@example.com", password: "password123"})

      {:ok, voter} =
        Accounts.create_user(%{email: "voter@example.com", password: "password123"})

      now = DateTime.utc_now()

      {:ok, market} =
        Markets.create_market(%{
          question: "Deep link test?",
          voting_start: now |> DateTime.add(-86400, :second),
          voting_end: now |> DateTime.add(-3600, :second),
          options: ["Yes", "No", "Maybe"]
        })

      option_yes = Enum.find(market.options, fn o -> o.label == "Yes" end)
      option_no = Enum.find(market.options, fn o -> o.label == "No" end)

      # Create votes for Yes (majority)
      Repo.insert!(%Vote{
        user_id: voter.id,
        market_id: market.id,
        market_option_id: option_yes.id
      })

      Repo.insert!(%Vote{
        user_id: user.id,
        market_id: market.id,
        market_option_id: option_yes.id
      })

      # Create another voter to vote No
      {:ok, voter2} =
        Accounts.create_user(%{
          email: "voter2_for_cross_004@example.com",
          password: "password123"
        })

      Repo.insert!(%Vote{
        user_id: voter2.id,
        market_id: market.id,
        market_option_id: option_no.id
      })

      # Resolve the market
      {:ok, resolved_market} = Markets.resolve_market(market)

      %{user: user, market: resolved_market, winning_option: option_yes}
    end

    test "notification contains a deep-link to the resolved market", %{
      conn: conn,
      user: user,
      market: market
    } do
      conn = login_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/notifications")

      # Should have a link to the market
      assert html =~ "href=\"/markets/#{market.id}\""
      assert html =~ "data-notification-market-id=\"#{market.id}\""
    end

    test "following notification link opens the resolved market page", %{
      conn: conn,
      user: user,
      market: market
    } do
      conn = login_user(conn, user)

      # Navigate from notifications
      {:ok, lv, _html} = live(conn, ~p"/notifications")
      assert has_element?(lv, "[data-notification-market-id='#{market.id}']")

      # Navigate to the market detail
      {:ok, detail_lv, _html} = live(conn, ~p"/markets/#{market.id}")

      # Should show resolved state
      assert has_element?(detail_lv, "[data-market-state='resolved']")
      assert has_element?(detail_lv, "[data-resolved-outcome]")
    end

    test "resolved market page shows the same outcome as the notification", %{
      conn: conn,
      user: user,
      market: market,
      winning_option: winning_option
    } do
      conn = login_user(conn, user)

      # Check notification message
      {:ok, _lv, notification_html} = live(conn, ~p"/notifications")
      assert notification_html =~ winning_option.label

      # Check market page shows same outcome
      {:ok, _lv, market_html} = live(conn, ~p"/markets/#{market.id}")

      # Should show the same winning option
      assert market_html =~ winning_option.label
      assert market_html =~ "data-outcome=\"majority\""

      # Should not show voting form
      refute market_html =~ "vote-form"
    end

    test "resolved market from notification does not have active vote control", %{
      conn: conn,
      user: user,
      market: market
    } do
      conn = login_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/markets/#{market.id}")

      # Should not have vote form
      refute has_element?(lv, "#vote-form")

      # User has already voted, so should see their vote recorded
      assert has_element?(lv, "[data-already-voted]")
    end
  end
end

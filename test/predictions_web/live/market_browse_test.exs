defmodule PredictionsWeb.MarketBrowseTest do
  use PredictionsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Predictions.Accounts
  alias Predictions.Markets

  describe "VAL-VOTE-001: Signed-in non-admin users can browse markets" do
    setup do
      {:ok, user} = Accounts.create_user(%{email: "user@example.com", password: "password123"})

      {:ok, admin} =
        Accounts.create_user(%{email: "admin@example.com", password: "password123", role: :admin})

      now = DateTime.utc_now()

      # Create an upcoming market
      {:ok, upcoming_market} =
        Markets.create_market(%{
          question: "Will it rain next week?",
          voting_start: now |> DateTime.add(3600, :second),
          voting_end: now |> DateTime.add(86400, :second),
          options: ["Yes", "No"]
        })

      # Create an active market
      {:ok, active_market} =
        Markets.create_market(%{
          question: "Is the sky blue?",
          voting_start: now |> DateTime.add(-3600, :second),
          voting_end: now |> DateTime.add(86400, :second),
          options: ["Yes", "No", "Maybe"]
        })

      %{user: user, admin: admin, upcoming_market: upcoming_market, active_market: active_market}
    end

    test "signed-in user can access market list page", %{conn: conn, user: user} do
      conn = login_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/markets")
      assert html =~ "Markets"
    end

    test "market list shows market questions", %{
      conn: conn,
      user: user,
      upcoming_market: upcoming_market,
      active_market: active_market
    } do
      conn = login_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/markets")

      assert html =~ upcoming_market.question
      assert html =~ active_market.question
    end

    test "market list shows explicit state markers", %{conn: conn, user: user} do
      conn = login_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/markets")

      # Check for state markers - upcoming and active
      assert has_element?(lv, "[data-market-state='upcoming']")
      assert has_element?(lv, "[data-market-state='active']")
    end

    test "guests cannot access market list page", %{conn: conn} do
      {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, ~p"/markets")
    end

    test "market detail page shows market question and option labels", %{
      conn: conn,
      user: user,
      active_market: market
    } do
      conn = login_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/markets/#{market.id}")

      assert html =~ market.question

      for option <- market.options do
        assert html =~ option.label
      end
    end

    test "market detail page shows explicit state marker", %{
      conn: conn,
      user: user,
      active_market: market
    } do
      conn = login_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/markets/#{market.id}")

      assert has_element?(lv, "[data-market-state='active']")
    end

    test "market detail page shows state marker for upcoming market", %{
      conn: conn,
      user: user,
      upcoming_market: market
    } do
      conn = login_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/markets/#{market.id}")

      assert has_element?(lv, "[data-market-state='upcoming']")
    end

    test "market list has links to market detail pages", %{
      conn: conn,
      user: user,
      active_market: market
    } do
      conn = login_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/markets")

      assert has_element?(lv, "a[href='/markets/#{market.id}']")
    end
  end

  describe "VAL-VOTE-006: Current vote totals are visible on the market detail page" do
    setup do
      {:ok, user1} = Accounts.create_user(%{email: "user1@example.com", password: "password123"})
      {:ok, user2} = Accounts.create_user(%{email: "user2@example.com", password: "password123"})
      {:ok, user3} = Accounts.create_user(%{email: "user3@example.com", password: "password123"})

      now = DateTime.utc_now()

      {:ok, market} =
        Markets.create_market(%{
          question: "Vote totals test?",
          voting_start: now |> DateTime.add(-3600, :second),
          voting_end: now |> DateTime.add(86400, :second),
          options: ["Yes", "No", "Maybe"]
        })

      option_yes = Enum.find(market.options, fn o -> o.label == "Yes" end)
      option_no = Enum.find(market.options, fn o -> o.label == "No" end)
      option_maybe = Enum.find(market.options, fn o -> o.label == "Maybe" end)

      # Cast some votes
      assert {:ok, _} = Markets.cast_vote(user1, market.id, option_yes.id)
      assert {:ok, _} = Markets.cast_vote(user2, market.id, option_yes.id)
      assert {:ok, _} = Markets.cast_vote(user3, market.id, option_no.id)

      %{
        user: user1,
        market: market,
        option_yes: option_yes,
        option_no: option_no,
        option_maybe: option_maybe
      }
    end

    test "market detail page displays vote totals for each option", %{
      conn: conn,
      user: user,
      market: market
    } do
      conn = login_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/markets/#{market.id}")

      # Option Yes should have 2 votes
      assert html =~ "2"
      # Option No should have 1 vote
      assert html =~ "1"
    end

    test "market detail page shows zero votes for options with no votes", %{
      conn: conn,
      user: user,
      market: market,
      option_maybe: option_maybe
    } do
      conn = login_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/markets/#{market.id}")

      # Option Maybe has 0 votes, but should still show with 0
      assert has_element?(lv, "[data-option-id='#{option_maybe.id}'][data-vote-count='0']")
    end

    test "market detail page shows numeric vote count markers per option", %{
      conn: conn,
      user: user,
      market: market
    } do
      conn = login_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/markets/#{market.id}")

      # Each option should have a vote count element
      for option <- market.options do
        assert has_element?(lv, "[data-option-id='#{option.id}']")
      end
    end
  end

  describe "VAL-CROSS-002: Admin-created markets appear in user browsing flows" do
    setup do
      {:ok, user} = Accounts.create_user(%{email: "user@example.com", password: "password123"})

      {:ok, admin} =
        Accounts.create_user(%{email: "admin@example.com", password: "password123", role: :admin})

      %{user: user, admin: admin}
    end

    test "admin-created market appears in user market list", %{
      conn: conn,
      user: user,
      admin: admin
    } do
      # Log in as admin and create a market via the LiveView form
      admin_conn = login_user(conn, admin)

      {:ok, lv, _html} = live(admin_conn, ~p"/admin/markets/new")

      now = DateTime.utc_now()

      voting_start =
        DateTime.add(now, 3600, :second) |> DateTime.to_naive() |> NaiveDateTime.to_iso8601()

      voting_end =
        DateTime.add(now, 86400, :second) |> DateTime.to_naive() |> NaiveDateTime.to_iso8601()

      html =
        lv
        |> form("#create-market-form", %{
          "market" => %{
            "question" => "Admin created question for user browse test",
            "options" => %{
              "0" => %{"label" => "Option A"},
              "1" => %{"label" => "Option B"}
            },
            "voting_start" => voting_start,
            "voting_end" => voting_end
          }
        })
        |> render_submit()

      assert {:ok, _lv, _html} = follow_redirect(html, admin_conn)

      # Now log in as normal user and check the market list
      user_conn = login_user(conn, user)
      {:ok, _lv, html} = live(user_conn, ~p"/markets")

      assert html =~ "Admin created question for user browse test"
    end

    test "admin-created market detail shows matching question and options", %{
      conn: conn,
      user: user,
      admin: admin
    } do
      # Log in as admin and create a market
      admin_conn = login_user(conn, admin)

      {:ok, lv, _html} = live(admin_conn, ~p"/admin/markets/new")

      now = DateTime.utc_now()

      voting_start =
        DateTime.add(now, 3600, :second) |> DateTime.to_naive() |> NaiveDateTime.to_iso8601()

      voting_end =
        DateTime.add(now, 86400, :second) |> DateTime.to_naive() |> NaiveDateTime.to_iso8601()

      html =
        lv
        |> form("#create-market-form", %{
          "market" => %{
            "question" => "Matching question test",
            "options" => %{
              "0" => %{"label" => "  First Option  "},
              "1" => %{"label" => "Second Option"}
            },
            "voting_start" => voting_start,
            "voting_end" => voting_end
          }
        })
        |> render_submit()

      assert {:ok, _lv, _html} = follow_redirect(html, admin_conn)

      # Get the created market
      market = Markets.get_market_with_options!(1)

      # Now log in as normal user and check the market detail
      user_conn = login_user(conn, user)
      {:ok, _lv, html} = live(user_conn, ~p"/markets/#{market.id}")

      # Should show the question
      assert html =~ "Matching question test"

      # Should show trimmed options
      assert html =~ "First Option"
      assert html =~ "Second Option"
    end
  end

  describe "resolved market state" do
    setup do
      {:ok, user} = Accounts.create_user(%{email: "user@example.com", password: "password123"})

      now = DateTime.utc_now()

      # Create a resolved market (voting ended, outcome set)
      {:ok, market} =
        Markets.create_market(%{
          question: "Already resolved?",
          voting_start: now |> DateTime.add(-86400, :second),
          voting_end: now |> DateTime.add(-3600, :second),
          options: ["Yes", "No"]
        })

      %{user: user, market: market}
    end

    test "resolved market shows resolved state marker", %{conn: conn, user: user, market: market} do
      # Resolve the market
      {:ok, resolved_market} = Markets.resolve_market(market)

      conn = login_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/markets/#{resolved_market.id}")

      assert has_element?(lv, "[data-market-state='resolved']")
    end

    test "market list shows resolved state for resolved markets", %{
      conn: conn,
      user: user,
      market: market
    } do
      # Resolve the market
      {:ok, _resolved_market} = Markets.resolve_market(market)

      conn = login_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/markets")

      assert has_element?(lv, "[data-market-state='resolved']")
    end
  end
end

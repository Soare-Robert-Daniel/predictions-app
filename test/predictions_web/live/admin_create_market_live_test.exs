defmodule PredictionsWeb.AdminCreateMarketLiveTest do
  use PredictionsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Predictions.Accounts
  alias Predictions.Markets
  alias Predictions.Markets.Market
  alias Predictions.Markets.MarketOption
  alias Predictions.Repo

  describe "VAL-MARKET-001: Admin can open the create-market form" do
    test "admin sees the create-market form with question, options, and voting window fields", %{
      conn: conn
    } do
      {:ok, admin} =
        Accounts.create_user(%{email: "admin@example.com", password: "password123", role: :admin})

      conn = login_user(conn, admin)

      {:ok, lv, html} = live(conn, ~p"/admin/markets/new")

      # Form marker
      assert has_element?(lv, "#create-market-form")

      # Question field marker
      assert has_element?(lv, "#create-market-form [name='market[question]']")
      assert html =~ "Question"

      # Multiple option field markers - at least 2 options
      assert has_element?(lv, "#create-market-form [name='market[options][0][label]']")
      assert has_element?(lv, "#create-market-form [name='market[options][1][label]']")
      assert html =~ "Option"

      # Voting window field markers
      assert has_element?(lv, "#create-market-form [name='market[voting_start]']")
      assert has_element?(lv, "#create-market-form [name='market[voting_end]']")
      assert html =~ "Voting"
    end

    test "create-market form has a submit control", %{conn: conn} do
      {:ok, admin} =
        Accounts.create_user(%{email: "admin@example.com", password: "password123", role: :admin})

      conn = login_user(conn, admin)

      {:ok, lv, _html} = live(conn, ~p"/admin/markets/new")

      assert has_element?(lv, "#create-market-form button[type='submit']")
    end
  end

  describe "VAL-MARKET-002: Valid market submission creates a market" do
    test "valid submission persists market with question, trimmed options in order, and voting timestamps",
         %{conn: conn} do
      {:ok, admin} =
        Accounts.create_user(%{email: "admin@example.com", password: "password123", role: :admin})

      conn = login_user(conn, admin)

      {:ok, lv, _html} = live(conn, ~p"/admin/markets/new")

      now = DateTime.utc_now()

      voting_start =
        DateTime.add(now, 3600, :second) |> DateTime.to_naive() |> NaiveDateTime.to_iso8601()

      voting_end =
        DateTime.add(now, 86400, :second) |> DateTime.to_naive() |> NaiveDateTime.to_iso8601()

      # Submit valid market using form params format that matches the HTML input names
      html =
        lv
        |> form("#create-market-form", %{
          "market" => %{
            "question" => "Will it rain tomorrow?",
            "options" => %{
              "0" => %{"label" => "  Yes  "},
              "1" => %{"label" => " No "},
              "2" => %{"label" => "  Maybe  "}
            },
            "voting_start" => voting_start,
            "voting_end" => voting_end
          }
        })
        |> render_submit()

      # Should redirect on success
      assert {:ok, _lv, _html} = follow_redirect(html, conn)

      # Verify market was created with expected data
      market = Markets.get_market_with_options!(1)
      assert market.question == "Will it rain tomorrow?"

      # Options should be trimmed and in order
      assert length(market.options) == 3
      assert Enum.at(market.options, 0).label == "Yes"
      assert Enum.at(market.options, 1).label == "No"
      assert Enum.at(market.options, 2).label == "Maybe"
    end

    test "extra blank options are ignored as long as at least 2 valid options exist", %{
      conn: conn
    } do
      {:ok, admin} =
        Accounts.create_user(%{email: "admin@example.com", password: "password123", role: :admin})

      conn = login_user(conn, admin)

      {:ok, lv, _html} = live(conn, ~p"/admin/markets/new")

      now = DateTime.utc_now()

      voting_start =
        DateTime.add(now, 3600, :second) |> DateTime.to_naive() |> NaiveDateTime.to_iso8601()

      voting_end =
        DateTime.add(now, 86400, :second) |> DateTime.to_naive() |> NaiveDateTime.to_iso8601()

      # Add an extra option slot to have 5 total
      lv |> element("button[phx-click='add_option']") |> render_click()

      html =
        lv
        |> form("#create-market-form", %{
          "market" => %{
            "question" => "Test with blanks?",
            "options" => %{
              "0" => %{"label" => ""},
              "1" => %{"label" => "  "},
              "2" => %{"label" => "Yes"},
              "3" => %{"label" => "No"},
              "4" => %{"label" => "   "}
            },
            "voting_start" => voting_start,
            "voting_end" => voting_end
          }
        })
        |> render_submit()

      assert {:ok, _lv, _html} = follow_redirect(html, conn)

      market = Markets.get_market_with_options!(1)
      assert length(market.options) == 2
      assert Enum.at(market.options, 0).label == "Yes"
      assert Enum.at(market.options, 1).label == "No"
    end
  end

  describe "VAL-MARKET-003: Blank question is rejected" do
    test "blank question shows validation error and does not create market", %{conn: conn} do
      {:ok, admin} =
        Accounts.create_user(%{email: "admin@example.com", password: "password123", role: :admin})

      conn = login_user(conn, admin)

      {:ok, lv, _html} = live(conn, ~p"/admin/markets/new")

      now = DateTime.utc_now()

      voting_start =
        DateTime.add(now, 3600, :second) |> DateTime.to_naive() |> NaiveDateTime.to_iso8601()

      voting_end =
        DateTime.add(now, 86400, :second) |> DateTime.to_naive() |> NaiveDateTime.to_iso8601()

      html =
        lv
        |> form("#create-market-form", %{
          "market" => %{
            "question" => "",
            "options" => %{
              "0" => %{"label" => "Yes"},
              "1" => %{"label" => "No"}
            },
            "voting_start" => voting_start,
            "voting_end" => voting_end
          }
        })
        |> render_submit()

      # Should show validation error
      assert html =~ "can&#39;t be blank"

      # No market should be created
      assert Repo.aggregate(Market, :count, :id) == 0
    end

    test "whitespace-only question shows validation error and does not create market", %{
      conn: conn
    } do
      {:ok, admin} =
        Accounts.create_user(%{email: "admin@example.com", password: "password123", role: :admin})

      conn = login_user(conn, admin)

      {:ok, lv, _html} = live(conn, ~p"/admin/markets/new")

      now = DateTime.utc_now()

      voting_start =
        DateTime.add(now, 3600, :second) |> DateTime.to_naive() |> NaiveDateTime.to_iso8601()

      voting_end =
        DateTime.add(now, 86400, :second) |> DateTime.to_naive() |> NaiveDateTime.to_iso8601()

      html =
        lv
        |> form("#create-market-form", %{
          "market" => %{
            "question" => "   ",
            "options" => %{
              "0" => %{"label" => "Yes"},
              "1" => %{"label" => "No"}
            },
            "voting_start" => voting_start,
            "voting_end" => voting_end
          }
        })
        |> render_submit()

      assert html =~ "can&#39;t be blank"
      assert Repo.aggregate(Market, :count, :id) == 0
    end
  end

  describe "VAL-MARKET-004: Invalid option sets are rejected" do
    test "fewer than 2 options shows validation error", %{conn: conn} do
      {:ok, admin} =
        Accounts.create_user(%{email: "admin@example.com", password: "password123", role: :admin})

      conn = login_user(conn, admin)

      {:ok, lv, _html} = live(conn, ~p"/admin/markets/new")

      now = DateTime.utc_now()

      voting_start =
        DateTime.add(now, 3600, :second) |> DateTime.to_naive() |> NaiveDateTime.to_iso8601()

      voting_end =
        DateTime.add(now, 86400, :second) |> DateTime.to_naive() |> NaiveDateTime.to_iso8601()

      html =
        lv
        |> form("#create-market-form", %{
          "market" => %{
            "question" => "Only one option?",
            "options" => %{
              "0" => %{"label" => "Only one"}
            },
            "voting_start" => voting_start,
            "voting_end" => voting_end
          }
        })
        |> render_submit()

      assert html =~ "must have at least 2 options"
      assert Repo.aggregate(Market, :count, :id) == 0
    end

    test "duplicate options (case-insensitive) shows validation error", %{conn: conn} do
      {:ok, admin} =
        Accounts.create_user(%{email: "admin@example.com", password: "password123", role: :admin})

      conn = login_user(conn, admin)

      {:ok, lv, _html} = live(conn, ~p"/admin/markets/new")

      now = DateTime.utc_now()

      voting_start =
        DateTime.add(now, 3600, :second) |> DateTime.to_naive() |> NaiveDateTime.to_iso8601()

      voting_end =
        DateTime.add(now, 86400, :second) |> DateTime.to_naive() |> NaiveDateTime.to_iso8601()

      html =
        lv
        |> form("#create-market-form", %{
          "market" => %{
            "question" => "Duplicate options?",
            "options" => %{
              "0" => %{"label" => "Yes"},
              "1" => %{"label" => "yes"},
              "2" => %{"label" => "No"}
            },
            "voting_start" => voting_start,
            "voting_end" => voting_end
          }
        })
        |> render_submit()

      assert html =~ "must not have duplicate labels"
      assert Repo.aggregate(Market, :count, :id) == 0
    end

    test "duplicate options (case-sensitive) shows validation error", %{conn: conn} do
      {:ok, admin} =
        Accounts.create_user(%{email: "admin@example.com", password: "password123", role: :admin})

      conn = login_user(conn, admin)

      {:ok, lv, _html} = live(conn, ~p"/admin/markets/new")

      now = DateTime.utc_now()

      voting_start =
        DateTime.add(now, 3600, :second) |> DateTime.to_naive() |> NaiveDateTime.to_iso8601()

      voting_end =
        DateTime.add(now, 86400, :second) |> DateTime.to_naive() |> NaiveDateTime.to_iso8601()

      html =
        lv
        |> form("#create-market-form", %{
          "market" => %{
            "question" => "Duplicate options?",
            "options" => %{
              "0" => %{"label" => "Yes"},
              "1" => %{"label" => "Yes"},
              "2" => %{"label" => "No"}
            },
            "voting_start" => voting_start,
            "voting_end" => voting_end
          }
        })
        |> render_submit()

      assert html =~ "must not have duplicate labels"
      assert Repo.aggregate(Market, :count, :id) == 0
    end
  end

  describe "VAL-MARKET-005: Invalid voting windows are rejected" do
    test "missing voting timestamps shows validation error", %{conn: conn} do
      {:ok, admin} =
        Accounts.create_user(%{email: "admin@example.com", password: "password123", role: :admin})

      conn = login_user(conn, admin)

      {:ok, lv, _html} = live(conn, ~p"/admin/markets/new")

      html =
        lv
        |> form("#create-market-form", %{
          "market" => %{
            "question" => "Missing timestamps?",
            "options" => %{
              "0" => %{"label" => "Yes"},
              "1" => %{"label" => "No"}
            },
            "voting_start" => "",
            "voting_end" => ""
          }
        })
        |> render_submit()

      assert html =~ "can&#39;t be blank"
      assert Repo.aggregate(Market, :count, :id) == 0
    end

    test "end time before start time shows validation error", %{conn: conn} do
      {:ok, admin} =
        Accounts.create_user(%{email: "admin@example.com", password: "password123", role: :admin})

      conn = login_user(conn, admin)

      {:ok, lv, _html} = live(conn, ~p"/admin/markets/new")

      now = DateTime.utc_now()
      # Start is after end
      voting_start =
        DateTime.add(now, 86400, :second) |> DateTime.to_naive() |> NaiveDateTime.to_iso8601()

      voting_end =
        DateTime.add(now, 3600, :second) |> DateTime.to_naive() |> NaiveDateTime.to_iso8601()

      html =
        lv
        |> form("#create-market-form", %{
          "market" => %{
            "question" => "Invalid window?",
            "options" => %{
              "0" => %{"label" => "Yes"},
              "1" => %{"label" => "No"}
            },
            "voting_start" => voting_start,
            "voting_end" => voting_end
          }
        })
        |> render_submit()

      assert html =~ "must be after voting start"
      assert Repo.aggregate(Market, :count, :id) == 0
    end
  end

  describe "VAL-MARKET-006: Unauthorized create submissions are rejected server-side" do
    test "guest create-market submission is rejected", %{conn: conn} do
      # Try to access the create-market route as a guest
      {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, ~p"/admin/markets/new")

      # No market should be created
      assert Repo.aggregate(Market, :count, :id) == 0
    end

    test "non-admin create-market submission is rejected", %{conn: conn} do
      {:ok, user} = Accounts.create_user(%{email: "user@example.com", password: "password123"})

      conn = login_user(conn, user)

      # Non-admin should be redirected away from admin area
      {:error, {:redirect, %{to: "/dashboard"}}} = live(conn, ~p"/admin/markets/new")

      # No market should be created
      assert Repo.aggregate(Market, :count, :id) == 0
      assert Repo.aggregate(MarketOption, :count, :id) == 0
    end
  end

  describe "VAL-MARKET-007: Invalid create submissions are atomic" do
    test "invalid submission does not leave partial market or option rows", %{conn: conn} do
      {:ok, admin} =
        Accounts.create_user(%{email: "admin@example.com", password: "password123", role: :admin})

      conn = login_user(conn, admin)

      {:ok, lv, _html} = live(conn, ~p"/admin/markets/new")

      initial_market_count = Repo.aggregate(Market, :count, :id)
      initial_option_count = Repo.aggregate(MarketOption, :count, :id)

      now = DateTime.utc_now()

      voting_start =
        DateTime.add(now, 3600, :second) |> DateTime.to_naive() |> NaiveDateTime.to_iso8601()

      voting_end =
        DateTime.add(now, 86400, :second) |> DateTime.to_naive() |> NaiveDateTime.to_iso8601()

      # Submit invalid market (blank question)
      _html =
        lv
        |> form("#create-market-form", %{
          "market" => %{
            "question" => "",
            "options" => %{
              "0" => %{"label" => "Yes"},
              "1" => %{"label" => "No"}
            },
            "voting_start" => voting_start,
            "voting_end" => voting_end
          }
        })
        |> render_submit()

      # No partial market or options should exist
      assert Repo.aggregate(Market, :count, :id) == initial_market_count
      assert Repo.aggregate(MarketOption, :count, :id) == initial_option_count
    end
  end
end

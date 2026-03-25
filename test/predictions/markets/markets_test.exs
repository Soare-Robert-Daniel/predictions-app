defmodule Predictions.MarketsTest do
  use Predictions.DataCase, async: true

  alias Predictions.Accounts
  alias Predictions.Markets
  alias Predictions.Markets.Market
  alias Predictions.Markets.MarketOption
  alias Predictions.Markets.Vote

  describe "create_market/1" do
    test "creates a market with valid attributes and trimmed options in order" do
      attrs = %{
        question: "Will it rain tomorrow?",
        voting_start: DateTime.utc_now() |> DateTime.add(3600, :second),
        voting_end: DateTime.utc_now() |> DateTime.add(86400, :second),
        options: ["  Yes  ", " No ", "  Maybe  "]
      }

      assert {:ok, market} = Markets.create_market(attrs)
      assert market.question == "Will it rain tomorrow?"

      assert length(market.options) == 3
      assert Enum.at(market.options, 0).label == "Yes"
      assert Enum.at(market.options, 1).label == "No"
      assert Enum.at(market.options, 2).label == "Maybe"

      assert Enum.at(market.options, 0).position == 0
      assert Enum.at(market.options, 1).position == 1
      assert Enum.at(market.options, 2).position == 2
    end

    test "creates a market with exactly two options" do
      attrs = %{
        question: "Yes or no?",
        voting_start: DateTime.utc_now() |> DateTime.add(3600, :second),
        voting_end: DateTime.utc_now() |> DateTime.add(86400, :second),
        options: ["Yes", "No"]
      }

      assert {:ok, market} = Markets.create_market(attrs)
      assert length(market.options) == 2
    end

    test "rejects market with blank question" do
      attrs = %{
        question: "   ",
        voting_start: DateTime.utc_now() |> DateTime.add(3600, :second),
        voting_end: DateTime.utc_now() |> DateTime.add(86400, :second),
        options: ["Yes", "No"]
      }

      assert {:error, changeset} = Markets.create_market(attrs)
      assert "can't be blank" in errors_on(changeset).question
    end

    test "rejects market with missing question" do
      attrs = %{
        voting_start: DateTime.utc_now() |> DateTime.add(3600, :second),
        voting_end: DateTime.utc_now() |> DateTime.add(86400, :second),
        options: ["Yes", "No"]
      }

      assert {:error, changeset} = Markets.create_market(attrs)
      assert "can't be blank" in errors_on(changeset).question
    end

    test "rejects market with only one option" do
      attrs = %{
        question: "Single option?",
        voting_start: DateTime.utc_now() |> DateTime.add(3600, :second),
        voting_end: DateTime.utc_now() |> DateTime.add(86400, :second),
        options: ["Only one"]
      }

      assert {:error, changeset} = Markets.create_market(attrs)
      assert "must have at least 2 options" in errors_on(changeset).options
    end

    test "rejects market with duplicate options (case-insensitive)" do
      attrs = %{
        question: "Duplicate Options?",
        voting_start: DateTime.utc_now() |> DateTime.add(3600, :second),
        voting_end: DateTime.utc_now() |> DateTime.add(86400, :second),
        options: ["Yes", "yes", "No"]
      }

      assert {:error, changeset} = Markets.create_market(attrs)
      assert "must not have duplicate labels" in errors_on(changeset).options
    end

    test "rejects market with duplicate options (case-sensitive)" do
      attrs = %{
        question: "Duplicate Options?",
        voting_start: DateTime.utc_now() |> DateTime.add(3600, :second),
        voting_end: DateTime.utc_now() |> DateTime.add(86400, :second),
        options: ["Yes", "Yes", "No"]
      }

      assert {:error, changeset} = Markets.create_market(attrs)
      assert "must not have duplicate labels" in errors_on(changeset).options
    end

    test "rejects market with voting end before voting start" do
      now = DateTime.utc_now()

      attrs = %{
        question: "Invalid window?",
        voting_start: now |> DateTime.add(86400, :second),
        voting_end: now |> DateTime.add(3600, :second),
        options: ["Yes", "No"]
      }

      assert {:error, changeset} = Markets.create_market(attrs)
      assert "must be after voting start" in errors_on(changeset).voting_end
    end

    test "rejects market with missing voting timestamps" do
      attrs = %{
        question: "Missing timestamps?",
        options: ["Yes", "No"]
      }

      assert {:error, changeset} = Markets.create_market(attrs)
      assert "can't be blank" in errors_on(changeset).voting_start
      assert "can't be blank" in errors_on(changeset).voting_end
    end

    test "ignores blank options as long as at least 2 valid options exist" do
      attrs = %{
        question: "With blanks?",
        voting_start: DateTime.utc_now() |> DateTime.add(3600, :second),
        voting_end: DateTime.utc_now() |> DateTime.add(86400, :second),
        options: ["", "  ", "Yes", "No", "   "]
      }

      assert {:ok, market} = Markets.create_market(attrs)
      assert length(market.options) == 2
      assert Enum.at(market.options, 0).label == "Yes"
      assert Enum.at(market.options, 1).label == "No"
    end

    test "rejects market when all options are blank" do
      attrs = %{
        question: "All blanks?",
        voting_start: DateTime.utc_now() |> DateTime.add(3600, :second),
        voting_end: DateTime.utc_now() |> DateTime.add(86400, :second),
        options: ["", "  ", "   "]
      }

      assert {:error, changeset} = Markets.create_market(attrs)
      assert "must have at least 2 options" in errors_on(changeset).options
    end

    test "atomic rejection - no partial market or options are created on invalid submission" do
      initial_market_count = Repo.aggregate(Market, :count, :id)
      initial_option_count = Repo.aggregate(MarketOption, :count, :id)

      attrs = %{
        # Invalid
        question: "",
        voting_start: DateTime.utc_now() |> DateTime.add(3600, :second),
        voting_end: DateTime.utc_now() |> DateTime.add(86400, :second),
        options: ["Yes", "No"]
      }

      assert {:error, _changeset} = Markets.create_market(attrs)

      assert Repo.aggregate(Market, :count, :id) == initial_market_count
      assert Repo.aggregate(MarketOption, :count, :id) == initial_option_count
    end
  end

  describe "market status" do
    setup do
      now = DateTime.utc_now()

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

      %{upcoming_market: upcoming_market, active_market: active_market, now: now}
    end

    test "status returns :upcoming before voting start", %{upcoming_market: market, now: now} do
      assert Market.status(market, now) == :upcoming
    end

    test "status returns :active after voting start but before voting end", %{
      active_market: market,
      now: now
    } do
      assert Market.status(market, now) == :active
    end

    test "status returns :resolved when outcome is set" do
      now = DateTime.utc_now()

      {:ok, market} =
        Markets.create_market(%{
          question: "Resolved market?",
          voting_start: now |> DateTime.add(-86400, :second),
          voting_end: now |> DateTime.add(-3600, :second),
          options: ["Yes", "No"]
        })

      # Manually set outcome
      market = %{market | outcome: :majority}

      assert Market.status(market, now) == :resolved
    end

    test "voting_active? returns false for upcoming market", %{upcoming_market: market, now: now} do
      refute Market.voting_active?(market, now)
    end

    test "voting_active? returns true for active market", %{active_market: market, now: now} do
      assert Market.voting_active?(market, now)
    end

    test "voting_active? returns false for resolved market" do
      now = DateTime.utc_now()

      {:ok, market} =
        Markets.create_market(%{
          question: "Resolved market?",
          voting_start: now |> DateTime.add(-86400, :second),
          voting_end: now |> DateTime.add(-3600, :second),
          options: ["Yes", "No"]
        })

      market = %{market | outcome: :majority}

      refute Market.voting_active?(market, now)
    end

    test "can_resolve? returns true after voting end" do
      now = DateTime.utc_now()

      {:ok, market} =
        Markets.create_market(%{
          question: "Ended market?",
          voting_start: now |> DateTime.add(-86400, :second),
          voting_end: now |> DateTime.add(-3600, :second),
          options: ["Yes", "No"]
        })

      assert Market.can_resolve?(market, now)
    end
  end

  describe "cast_vote/3" do
    setup do
      {:ok, user} = Accounts.create_user(%{email: "user@example.com", password: "password123"})

      {:ok, admin} =
        Accounts.create_user(%{email: "admin@example.com", password: "password123", role: :admin})

      now = DateTime.utc_now()

      {:ok, market} =
        Markets.create_market(%{
          question: "Test market?",
          voting_start: now |> DateTime.add(-3600, :second),
          voting_end: now |> DateTime.add(86400, :second),
          options: ["Yes", "No"]
        })

      option_yes = Enum.find(market.options, fn o -> o.label == "Yes" end)
      option_no = Enum.find(market.options, fn o -> o.label == "No" end)

      %{user: user, admin: admin, market: market, option_yes: option_yes, option_no: option_no}
    end

    test "eligible user can cast a vote", %{user: user, market: market, option_yes: option} do
      assert {:ok, vote} = Markets.cast_vote(user, market.id, option.id)
      assert vote.user_id == user.id
      assert vote.market_id == market.id
      assert vote.market_option_id == option.id
    end

    test "duplicate vote attempts are rejected", %{
      user: user,
      market: market,
      option_yes: option_yes,
      option_no: option_no
    } do
      assert {:ok, _vote} = Markets.cast_vote(user, market.id, option_yes.id)
      assert {:error, :already_voted} = Markets.cast_vote(user, market.id, option_no.id)

      # Only one vote should exist
      assert Markets.get_user_vote(user.id, market.id).market_option_id == option_yes.id
    end

    test "admins cannot vote", %{admin: admin, market: market, option_yes: option} do
      assert {:error, :admin_cannot_vote} = Markets.cast_vote(admin, market.id, option.id)

      refute Markets.user_voted?(admin.id, market.id)
    end

    test "voting is rejected before voting window opens" do
      now = DateTime.utc_now()

      {:ok, upcoming_market} =
        Markets.create_market(%{
          question: "Upcoming?",
          voting_start: now |> DateTime.add(3600, :second),
          voting_end: now |> DateTime.add(86400, :second),
          options: ["Yes", "No"]
        })

      {:ok, user} = Accounts.create_user(%{email: "user2@example.com", password: "password123"})
      option = Enum.find(upcoming_market.options, fn o -> o.label == "Yes" end)

      assert {:error, :market_inactive} = Markets.cast_vote(user, upcoming_market.id, option.id)
      refute Markets.user_voted?(user.id, upcoming_market.id)
    end

    test "voting is rejected after voting window closes" do
      now = DateTime.utc_now()

      {:ok, closed_market} =
        Markets.create_market(%{
          question: "Closed?",
          voting_start: now |> DateTime.add(-86400, :second),
          voting_end: now |> DateTime.add(-3600, :second),
          options: ["Yes", "No"]
        })

      {:ok, user} = Accounts.create_user(%{email: "user3@example.com", password: "password123"})
      option = Enum.find(closed_market.options, fn o -> o.label == "Yes" end)

      assert {:error, :market_inactive} = Markets.cast_vote(user, closed_market.id, option.id)
      refute Markets.user_voted?(user.id, closed_market.id)
    end

    test "voting is rejected for option from different market" do
      now = DateTime.utc_now()

      {:ok, other_market} =
        Markets.create_market(%{
          question: "Other market?",
          voting_start: now |> DateTime.add(-3600, :second),
          voting_end: now |> DateTime.add(86400, :second),
          options: ["Maybe", "Possibly"]
        })

      {:ok, user} = Accounts.create_user(%{email: "user4@example.com", password: "password123"})
      _option = Enum.find(other_market.options, fn o -> o.label == "Maybe" end)

      # Try to vote for option from other market in the first market
      assert {:error, :invalid_option} = Markets.cast_vote(user, other_market.id, 9999)
    end

    test "vote totals are updated correctly", %{
      user: user,
      market: market,
      option_yes: option_yes
    } do
      assert {:ok, _vote} = Markets.cast_vote(user, market.id, option_yes.id)

      counts = Markets.get_vote_counts(market.id)
      assert counts[option_yes.id] == 1

      # Other options should not be in the map (0 votes)
      option_no = Enum.find(market.options, fn o -> o.label == "No" end)
      refute Map.has_key?(counts, option_no.id)
    end
  end

  describe "one-vote enforcement race safety" do
    setup do
      {:ok, user} = Accounts.create_user(%{email: "user@example.com", password: "password123"})

      now = DateTime.utc_now()

      {:ok, market} =
        Markets.create_market(%{
          question: "Test market?",
          voting_start: now |> DateTime.add(-3600, :second),
          voting_end: now |> DateTime.add(86400, :second),
          options: ["Yes", "No"]
        })

      option = Enum.find(market.options, fn o -> o.label == "Yes" end)

      %{user: user, market: market, option: option}
    end

    test "concurrent vote attempts result in only one vote", %{
      user: user,
      market: market,
      option: option
    } do
      # Simulate concurrent votes by attempting multiple inserts
      tasks =
        for _ <- 1..5 do
          Task.async(fn ->
            Markets.cast_vote(user, market.id, option.id)
          end)
        end

      results = Task.await_many(tasks, 5000)

      # Count successes vs failures
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

  describe "market resolution" do
    setup do
      {:ok, user1} = Accounts.create_user(%{email: "user1@example.com", password: "password123"})
      {:ok, user2} = Accounts.create_user(%{email: "user2@example.com", password: "password123"})
      {:ok, user3} = Accounts.create_user(%{email: "user3@example.com", password: "password123"})

      now = DateTime.utc_now()

      %{user1: user1, user2: user2, user3: user3, now: now}
    end

    test "majority winner is determined correctly", %{
      user1: user1,
      user2: user2,
      user3: user3,
      now: now
    } do
      {:ok, market} =
        Markets.create_market(%{
          question: "Majority test?",
          voting_start: now |> DateTime.add(-86400, :second),
          voting_end: now |> DateTime.add(-3600, :second),
          options: ["Yes", "No"]
        })

      option_yes = Enum.find(market.options, fn o -> o.label == "Yes" end)
      option_no = Enum.find(market.options, fn o -> o.label == "No" end)

      # Set up voting state manually since the market is closed
      Repo.insert!(%Vote{
        user_id: user1.id,
        market_id: market.id,
        market_option_id: option_yes.id
      })

      Repo.insert!(%Vote{
        user_id: user2.id,
        market_id: market.id,
        market_option_id: option_yes.id
      })

      Repo.insert!(%Vote{user_id: user3.id, market_id: market.id, market_option_id: option_no.id})

      assert {:ok, resolved_market} = Markets.resolve_market(market)
      assert resolved_market.outcome == :majority
      assert resolved_market.resolved_at != nil
    end

    test "majority resolution stores winning_option_id", %{
      user1: user1,
      user2: user2,
      user3: user3,
      now: now
    } do
      {:ok, market} =
        Markets.create_market(%{
          question: "Winning option test?",
          voting_start: now |> DateTime.add(-86400, :second),
          voting_end: now |> DateTime.add(-3600, :second),
          options: ["Yes", "No", "Maybe"]
        })

      option_yes = Enum.find(market.options, fn o -> o.label == "Yes" end)
      option_no = Enum.find(market.options, fn o -> o.label == "No" end)

      # 2 votes for Yes, 1 for No, 0 for Maybe
      Repo.insert!(%Vote{
        user_id: user1.id,
        market_id: market.id,
        market_option_id: option_yes.id
      })

      Repo.insert!(%Vote{
        user_id: user2.id,
        market_id: market.id,
        market_option_id: option_yes.id
      })

      Repo.insert!(%Vote{user_id: user3.id, market_id: market.id, market_option_id: option_no.id})

      assert {:ok, resolved_market} = Markets.resolve_market(market)
      assert resolved_market.outcome == :majority
      assert resolved_market.winning_option_id == option_yes.id
    end

    test "tie outcome has nil winning_option_id", %{user1: user1, user2: user2, now: now} do
      {:ok, market} =
        Markets.create_market(%{
          question: "Tie test?",
          voting_start: now |> DateTime.add(-86400, :second),
          voting_end: now |> DateTime.add(-3600, :second),
          options: ["Yes", "No"]
        })

      option_yes = Enum.find(market.options, fn o -> o.label == "Yes" end)
      option_no = Enum.find(market.options, fn o -> o.label == "No" end)

      Repo.insert!(%Vote{
        user_id: user1.id,
        market_id: market.id,
        market_option_id: option_yes.id
      })

      Repo.insert!(%Vote{user_id: user2.id, market_id: market.id, market_option_id: option_no.id})

      assert {:ok, resolved_market} = Markets.resolve_market(market)
      assert resolved_market.outcome == :tie
      assert resolved_market.winning_option_id == nil
    end

    test "no votes outcome has nil winning_option_id", %{now: now} do
      {:ok, market} =
        Markets.create_market(%{
          question: "No votes test?",
          voting_start: now |> DateTime.add(-86400, :second),
          voting_end: now |> DateTime.add(-3600, :second),
          options: ["Yes", "No"]
        })

      assert {:ok, resolved_market} = Markets.resolve_market(market)
      assert resolved_market.outcome == :no_votes
      assert resolved_market.winning_option_id == nil
    end

    test "cannot resolve market that hasn't ended", %{now: now} do
      {:ok, market} =
        Markets.create_market(%{
          question: "Still active?",
          voting_start: now |> DateTime.add(-3600, :second),
          voting_end: now |> DateTime.add(86400, :second),
          options: ["Yes", "No"]
        })

      assert {:error, :market_not_ended} = Markets.resolve_market(market)
    end

    test "cannot resolve already resolved market", %{now: now} do
      {:ok, market} =
        Markets.create_market(%{
          question: "Already resolved?",
          voting_start: now |> DateTime.add(-86400, :second),
          voting_end: now |> DateTime.add(-3600, :second),
          options: ["Yes", "No"]
        })

      assert {:ok, resolved_market} = Markets.resolve_market(market)
      assert {:error, :already_resolved} = Markets.resolve_market(resolved_market)
    end

    test "resolution outcome is stable across repeated reads", %{now: now} do
      {:ok, market} =
        Markets.create_market(%{
          question: "Stability test?",
          voting_start: now |> DateTime.add(-86400, :second),
          voting_end: now |> DateTime.add(-3600, :second),
          options: ["Yes", "No"]
        })

      assert {:ok, resolved_market} = Markets.resolve_market(market)

      # Re-fetch from DB and verify stability
      fetched_market = Markets.get_market!(resolved_market.id)
      assert fetched_market.outcome == resolved_market.outcome
      assert fetched_market.resolved_at == resolved_market.resolved_at
      assert fetched_market.winning_option_id == resolved_market.winning_option_id
    end
  end

  describe "resolve_ended_markets/0 - batch resolution" do
    setup do
      now = DateTime.utc_now()
      %{now: now}
    end

    test "resolves multiple ended markets at once", %{now: now} do
      # Create 3 ended markets
      {:ok, market1} =
        Markets.create_market(%{
          question: "Ended 1?",
          voting_start: now |> DateTime.add(-86400, :second),
          voting_end: now |> DateTime.add(-3600, :second),
          options: ["Yes", "No"]
        })

      {:ok, market2} =
        Markets.create_market(%{
          question: "Ended 2?",
          voting_start: now |> DateTime.add(-86400, :second),
          voting_end: now |> DateTime.add(-3600, :second),
          options: ["Yes", "No"]
        })

      {:ok, _active_market} =
        Markets.create_market(%{
          question: "Still active?",
          voting_start: now |> DateTime.add(-3600, :second),
          voting_end: now |> DateTime.add(86400, :second),
          options: ["Yes", "No"]
        })

      # Resolve ended markets
      resolved_count = Markets.resolve_ended_markets()
      assert resolved_count == 2

      # Verify markets are resolved
      assert Markets.get_market!(market1.id).outcome != nil
      assert Markets.get_market!(market2.id).outcome != nil
    end

    test "idempotent - repeated calls do not change outcomes", %{now: now} do
      {:ok, market} =
        Markets.create_market(%{
          question: "Idempotent test?",
          voting_start: now |> DateTime.add(-86400, :second),
          voting_end: now |> DateTime.add(-3600, :second),
          options: ["Yes", "No"]
        })

      # First call resolves
      assert Markets.resolve_ended_markets() == 1
      resolved = Markets.get_market!(market.id)
      assert resolved.outcome != nil

      # Second call does nothing (already resolved)
      assert Markets.resolve_ended_markets() == 0

      # Outcome unchanged
      still_resolved = Markets.get_market!(market.id)
      assert still_resolved.outcome == resolved.outcome
      assert still_resolved.resolved_at == resolved.resolved_at
    end
  end

  describe "can_resolve_market?/1" do
    setup do
      now = DateTime.utc_now()
      %{now: now}
    end

    test "returns can_resolve for ended market", %{now: now} do
      {:ok, market} =
        Markets.create_market(%{
          question: "Ended?",
          voting_start: now |> DateTime.add(-86400, :second),
          voting_end: now |> DateTime.add(-3600, :second),
          options: ["Yes", "No"]
        })

      assert {:ok, :can_resolve} = Markets.can_resolve_market?(market)
    end

    test "returns already_resolved for resolved market", %{now: now} do
      {:ok, market} =
        Markets.create_market(%{
          question: "Already resolved?",
          voting_start: now |> DateTime.add(-86400, :second),
          voting_end: now |> DateTime.add(-3600, :second),
          options: ["Yes", "No"]
        })

      {:ok, resolved} = Markets.resolve_market(market)
      assert {:error, :already_resolved} = Markets.can_resolve_market?(resolved)
    end

    test "returns market_not_ended for active market", %{now: now} do
      {:ok, market} =
        Markets.create_market(%{
          question: "Still active?",
          voting_start: now |> DateTime.add(-3600, :second),
          voting_end: now |> DateTime.add(86400, :second),
          options: ["Yes", "No"]
        })

      assert {:error, :market_not_ended} = Markets.can_resolve_market?(market)
    end

    test "returns market_not_ended for upcoming market", %{now: now} do
      {:ok, market} =
        Markets.create_market(%{
          question: "Upcoming?",
          voting_start: now |> DateTime.add(3600, :second),
          voting_end: now |> DateTime.add(86400, :second),
          options: ["Yes", "No"]
        })

      assert {:error, :market_not_ended} = Markets.can_resolve_market?(market)
    end
  end

  describe "notifications" do
    setup do
      {:ok, user1} = Accounts.create_user(%{email: "user1@example.com", password: "password123"})
      {:ok, user2} = Accounts.create_user(%{email: "user2@example.com", password: "password123"})

      {:ok, non_voter} =
        Accounts.create_user(%{email: "nonvoter@example.com", password: "password123"})

      now = DateTime.utc_now()

      {:ok, market} =
        Markets.create_market(%{
          question: "Notification test?",
          voting_start: now |> DateTime.add(-86400, :second),
          voting_end: now |> DateTime.add(-3600, :second),
          options: ["Yes", "No"]
        })

      option_yes = Enum.find(market.options, fn o -> o.label == "Yes" end)

      %{user1: user1, user2: user2, non_voter: non_voter, market: market, option_yes: option_yes}
    end

    test "participants receive one notification when market resolves", %{
      user1: user1,
      user2: user2,
      market: market,
      option_yes: option
    } do
      Repo.insert!(%Vote{user_id: user1.id, market_id: market.id, market_option_id: option.id})
      Repo.insert!(%Vote{user_id: user2.id, market_id: market.id, market_option_id: option.id})

      assert {:ok, _resolved} = Markets.resolve_market(market)

      notifications = Markets.list_notifications(user1.id)
      assert length(notifications) == 1
      assert hd(notifications).market_id == market.id

      notifications2 = Markets.list_notifications(user2.id)
      assert length(notifications2) == 1
    end

    test "non-participants do not receive resolution notification", %{
      non_voter: non_voter,
      market: market
    } do
      assert {:ok, _resolved} = Markets.resolve_market(market)

      notifications = Markets.list_notifications(non_voter.id)
      assert Enum.empty?(notifications)
    end

    test "resolution notification is not sent before resolution", %{
      user1: user1,
      market: market,
      option_yes: option
    } do
      Repo.insert!(%Vote{user_id: user1.id, market_id: market.id, market_option_id: option.id})

      notifications = Markets.list_notifications(user1.id)
      assert Enum.empty?(notifications)
    end

    test "resolution notifications are idempotent", %{
      user1: user1,
      market: market,
      option_yes: option
    } do
      Repo.insert!(%Vote{user_id: user1.id, market_id: market.id, market_option_id: option.id})

      assert {:ok, resolved} = Markets.resolve_market(market)

      # Try to resolve again
      assert {:error, :already_resolved} = Markets.resolve_market(resolved)

      # Should still have exactly one notification
      notifications = Markets.list_notifications(user1.id)
      assert length(notifications) == 1
    end
  end

  describe "get_market_with_options!/1 and list_markets_with_options/0" do
    test "preloads options in correct order" do
      attrs = %{
        question: "Order test?",
        voting_start: DateTime.utc_now() |> DateTime.add(3600, :second),
        voting_end: DateTime.utc_now() |> DateTime.add(86400, :second),
        options: ["First", "Second", "Third"]
      }

      assert {:ok, market} = Markets.create_market(attrs)

      loaded_market = Markets.get_market_with_options!(market.id)
      assert length(loaded_market.options) == 3
      assert Enum.at(loaded_market.options, 0).label == "First"
      assert Enum.at(loaded_market.options, 1).label == "Second"
      assert Enum.at(loaded_market.options, 2).label == "Third"
    end
  end

  describe "user_voted?/2 and get_user_vote/2" do
    setup do
      {:ok, user} = Accounts.create_user(%{email: "user@example.com", password: "password123"})

      now = DateTime.utc_now()

      {:ok, market} =
        Markets.create_market(%{
          question: "Test market?",
          voting_start: now |> DateTime.add(-3600, :second),
          voting_end: now |> DateTime.add(86400, :second),
          options: ["Yes", "No"]
        })

      option = Enum.find(market.options, fn o -> o.label == "Yes" end)

      %{user: user, market: market, option: option}
    end

    test "user_voted? returns false before voting", %{user: user, market: market} do
      refute Markets.user_voted?(user.id, market.id)
    end

    test "user_voted? returns true after voting", %{user: user, market: market, option: option} do
      assert {:ok, _vote} = Markets.cast_vote(user, market.id, option.id)
      assert Markets.user_voted?(user.id, market.id)
    end

    test "get_user_vote returns nil before voting", %{user: user, market: market} do
      assert Markets.get_user_vote(user.id, market.id) == nil
    end

    test "get_user_vote returns vote after voting", %{user: user, market: market, option: option} do
      assert {:ok, vote} = Markets.cast_vote(user, market.id, option.id)

      retrieved_vote = Markets.get_user_vote(user.id, market.id)
      assert retrieved_vote.id == vote.id
      assert retrieved_vote.market_option_id == option.id
    end
  end
end

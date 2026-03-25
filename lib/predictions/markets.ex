defmodule Predictions.Markets do
  @moduledoc """
  The Markets context module for market management and voting.

  This context handles:
  - Market creation with validation
  - Market querying and listing
  - Vote submission with integrity guarantees
  - Market resolution
  - Notification management
  """

  import Ecto.Query, warn: false
  import Ecto.Changeset
  alias Predictions.Repo
  alias Predictions.Accounts.User
  alias Predictions.Markets.Market
  alias Predictions.Markets.MarketOption
  alias Predictions.Markets.Vote
  alias Predictions.Markets.Notification

  # --- Market Management ---

  @doc """
  Returns the list of all markets.
  """
  @spec list_markets() :: [Market.t()]
  def list_markets do
    from(m in Market, order_by: [desc: m.inserted_at])
    |> Repo.all()
  end

  @doc """
  Returns the list of markets with options preloaded.
  """
  @spec list_markets_with_options() :: [Market.t()]
  def list_markets_with_options do
    from(m in Market, order_by: [desc: m.inserted_at])
    |> preload(options: ^from(o in MarketOption, order_by: o.position))
    |> preload(:winning_option)
    |> Repo.all()
  end

  @doc """
  Gets a single market.
  Raises `Ecto.NoResultsError` if the market does not exist.
  """
  @spec get_market!(integer()) :: Market.t()
  def get_market!(id) do
    Repo.get!(Market, id)
  end

  @doc """
  Gets a single market with options preloaded.
  Raises `Ecto.NoResultsError` if the market does not exist.
  """
  @spec get_market_with_options!(integer()) :: Market.t()
  def get_market_with_options!(id) do
    from(m in Market, where: m.id == ^id)
    |> preload(options: ^from(o in MarketOption, order_by: o.position))
    |> maybe_preload_winning_option()
    |> Repo.one!()
  end

  # Preload winning_option for resolved markets with majority outcome
  defp maybe_preload_winning_option(query) do
    from(m in query, preload: :winning_option)
  end

  @doc """
  Gets a market by ID. Returns nil if not found.
  """
  @spec get_market(integer()) :: Market.t() | nil
  def get_market(id) when is_integer(id) do
    Repo.get(Market, id)
  end

  def get_market(_), do: nil

  @doc """
  Creates a new market with options.

  ## Attributes

  - `:question` - Required, non-blank string
  - `:voting_start` - Required, UTC datetime
  - `:voting_end` - Required, UTC datetime, must be after voting_start
  - `:options` - Required, list of at least 2 unique non-blank labels

  ## Examples

      iex> create_market(%{question: "Will it rain?", voting_start: ~U[2024-01-01 10:00:00Z], voting_end: ~U[2024-01-02 10:00:00Z], options: ["Yes", "No"]})
      {:ok, %Market{}}

      iex> create_market(%{question: "", options: []})
      {:error, %Ecto.Changeset{}}
  """
  @spec create_market(map()) :: {:ok, Market.t()} | {:error, Ecto.Changeset.t()}
  def create_market(attrs) do
    # Use a transaction to ensure atomicity
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:market, Market.create_changeset(%Market{}, attrs))
    |> Repo.transaction()
    |> case do
      {:ok, %{market: market}} ->
        # Reload with options
        {:ok, get_market_with_options!(market.id)}

      {:error, :market, changeset, _} ->
        {:error, changeset}
    end
  end

  @doc """
  Updates a market.
  """
  @spec update_market(Market.t(), map()) :: {:ok, Market.t()} | {:error, Ecto.Changeset.t()}
  def update_market(%Market{} = market, attrs) do
    market
    |> cast(attrs, [:question, :voting_start, :voting_end])
    |> validate_required([:question, :voting_start, :voting_end])
    |> Repo.update()
  end

  @doc """
  Deletes a market.
  """
  @spec delete_market(Market.t()) :: {:ok, Market.t()} | {:error, Ecto.Changeset.t()}
  def delete_market(%Market{} = market) do
    Repo.delete(market)
  end

  @doc """
  Returns a changeset for tracking market changes.
  """
  @spec change_market(Market.t(), map()) :: Ecto.Changeset.t()
  def change_market(%Market{} = market, attrs \\ %{}) do
    Market.create_changeset(market, attrs)
  end

  # --- Market Status ---

  @doc """
  Returns the status of a market based on current time.
  """
  @spec market_status(Market.t(), DateTime.t()) :: :upcoming | :active | :resolved
  def market_status(%Market{} = market, now \\ DateTime.utc_now()) do
    Market.status(market, now)
  end

  @doc """
  Returns true if voting is currently active for the market.
  """
  @spec voting_active?(Market.t(), DateTime.t()) :: boolean()
  def voting_active?(%Market{} = market, now \\ DateTime.utc_now()) do
    Market.voting_active?(market, now)
  end

  # --- Market Options ---

  @doc """
  Gets an option by ID with market preloaded.
  """
  @spec get_option!(integer()) :: MarketOption.t()
  def get_option!(id) do
    Repo.get!(MarketOption, id)
  end

  @doc """
  Gets an option by ID. Returns nil if not found.
  """
  @spec get_option(integer()) :: MarketOption.t() | nil
  def get_option(id) when is_integer(id) do
    Repo.get(MarketOption, id)
  end

  def get_option(_), do: nil

  @doc """
  Returns all options for a market with vote counts.
  """
  @spec list_options_with_vote_counts(integer()) :: [{MarketOption.t(), non_neg_integer()}]
  def list_options_with_vote_counts(market_id) do
    from(o in MarketOption,
      where: o.market_id == ^market_id,
      order_by: o.position,
      left_join: v in Vote,
      on: v.market_option_id == o.id,
      group_by: o.id,
      select: {o, count(v.id)}
    )
    |> Repo.all()
  end

  # --- Voting ---

  @doc """
  Checks if a user has already voted in a market.
  """
  @spec user_voted?(integer(), integer()) :: boolean()
  def user_voted?(user_id, market_id) do
    from(v in Vote, where: v.user_id == ^user_id and v.market_id == ^market_id)
    |> Repo.exists?()
  end

  @doc """
  Gets a user's vote for a specific market.
  Returns nil if the user hasn't voted.
  """
  @spec get_user_vote(integer(), integer()) :: Vote.t() | nil
  def get_user_vote(user_id, market_id) do
    from(v in Vote, where: v.user_id == ^user_id and v.market_id == ^market_id)
    |> Repo.one()
  end

  @doc """
  Submits a vote for a market.

  ## Constraints

  - User must not have already voted in the market
  - Market must be active (within voting window)
  - Option must belong to the market
  - User must not be an admin

  ## Examples

      iex> cast_vote(user, market_id, option_id)
      {:ok, %Vote{}}

      iex> cast_vote(user, market_id, option_id) # already voted
      {:error, :already_voted}
  """
  @spec cast_vote(User.t(), integer(), integer()) ::
          {:ok, Vote.t()}
          | {:error, :already_voted | :market_inactive | :invalid_option | Ecto.Changeset.t()}
  def cast_vote(%User{role: :admin}, _market_id, _option_id) do
    {:error, :admin_cannot_vote}
  end

  def cast_vote(%User{id: user_id}, market_id, option_id) do
    now = DateTime.utc_now()

    # Verify market is active
    market = get_market!(market_id)

    if not Market.voting_active?(market, now) do
      {:error, :market_inactive}
    else
      # Verify option belongs to market
      option = get_option(option_id)

      if is_nil(option) or option.market_id != market_id do
        {:error, :invalid_option}
      else
        # Create vote with unique constraint handling
        %Vote{}
        |> Vote.changeset(%{
          user_id: user_id,
          market_id: market_id,
          market_option_id: option_id
        })
        |> Repo.insert()
        |> case do
          {:ok, vote} ->
            {:ok, vote}

          {:error, changeset} ->
            # Check for unique constraint violation on user_id/market_id
            if has_unique_violation?(changeset, :user_id) do
              {:error, :already_voted}
            else
              {:error, changeset}
            end
        end
      end
    end
  end

  @doc """
  Returns the vote counts for all options in a market.
  """
  @spec get_vote_counts(integer()) :: %{integer() => non_neg_integer()}
  def get_vote_counts(market_id) do
    from(v in Vote,
      where: v.market_id == ^market_id,
      group_by: v.market_option_id,
      select: {v.market_option_id, count(v.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Returns the total number of votes for a market.
  """
  @spec total_votes(integer()) :: non_neg_integer()
  def total_votes(market_id) do
    from(v in Vote, where: v.market_id == ^market_id)
    |> Repo.aggregate(:count, :id)
  end

  # --- Market Resolution ---

  @doc """
  Resolves a market based on vote counts.

  Returns:
  - `{:ok, market}` with outcome :majority if one option has the most votes
  - `{:ok, market}` with outcome :tie if multiple options tie for highest
  - `{:ok, market}` with outcome :no_votes if there are no votes

  Returns error if:
  - Market is already resolved (`:already_resolved`)
  - Market hasn't ended yet (`:market_not_ended`)

  The resolution is idempotent - calling it multiple times on an already
  resolved market will return an error without changing the outcome.
  """
  @spec resolve_market(Market.t()) ::
          {:ok, Market.t()} | {:error, :market_not_ended | :already_resolved}
  def resolve_market(%Market{outcome: outcome}) when not is_nil(outcome) do
    {:error, :already_resolved}
  end

  def resolve_market(%Market{id: market_id} = market) do
    now = DateTime.utc_now()

    if not Market.can_resolve?(market, now) do
      {:error, :market_not_ended}
    else
      # Get options with vote counts
      options_with_counts = list_options_with_vote_counts(market_id)

      {outcome, winning_option_id} = determine_outcome(options_with_counts)

      changeset = Market.resolve_changeset(market, outcome, winning_option_id)

      Ecto.Multi.new()
      |> Ecto.Multi.update(:market, changeset)
      |> Ecto.Multi.run(:notifications, fn _repo, _changes ->
        create_resolution_notifications(market_id, outcome, winning_option_id)
        {:ok, :created}
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{market: updated_market}} ->
          # Reload with winning_option preloaded
          {:ok, get_market_with_options!(updated_market.id)}

        {:error, :market, changeset, _} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Resolves all markets that have ended but haven't been resolved yet.

  This function is idempotent - it can be called repeatedly without
  causing duplicate resolutions or notifications.

  Returns the number of markets that were resolved.
  """
  @spec resolve_ended_markets() :: non_neg_integer()
  def resolve_ended_markets do
    now = DateTime.utc_now()

    # Find all markets that have ended but are not yet resolved
    ended_unresolved =
      from(m in Market,
        where: is_nil(m.outcome) and m.voting_end <= ^now,
        select: m.id
      )
      |> Repo.all()

    # Resolve each market
    resolved_count =
      ended_unresolved
      |> Enum.count(fn market_id ->
        market = get_market!(market_id)
        {:ok, _} = resolve_market(market)
        true
      end)

    resolved_count
  end

  @doc """
  Checks if a market can be resolved without actually resolving it.

  Returns:
  - `{:ok, :can_resolve}` if the market has ended and is not resolved
  - `{:error, :already_resolved}` if already resolved
  - `{:error, :market_not_ended}` if still active
  """
  @spec can_resolve_market?(Market.t()) ::
          {:ok, :can_resolve} | {:error, :already_resolved | :market_not_ended}
  def can_resolve_market?(%Market{outcome: outcome}) when not is_nil(outcome) do
    {:error, :already_resolved}
  end

  def can_resolve_market?(%Market{} = market) do
    now = DateTime.utc_now()

    if Market.can_resolve?(market, now) do
      {:ok, :can_resolve}
    else
      {:error, :market_not_ended}
    end
  end

  # Determines the outcome based on vote counts.
  # Returns {outcome, winning_option_id} where winning_option_id is:
  # - The winning option's ID for :majority
  # - nil for :tie and :no_votes
  defp determine_outcome(options_with_counts) do
    if Enum.empty?(options_with_counts) do
      {:no_votes, nil}
    else
      # Get max vote count
      max_count =
        options_with_counts
        |> Enum.map(fn {_option, count} -> count end)
        |> Enum.max()

      if max_count == 0 do
        {:no_votes, nil}
      else
        # Find options with max count
        winners =
          options_with_counts
          |> Enum.filter(fn {_option, count} -> count == max_count end)
          |> Enum.map(fn {option, _count} -> option end)

        case length(winners) do
          1 ->
            {:majority, hd(winners).id}

          _ ->
            {:tie, nil}
        end
      end
    end
  end

  defp create_resolution_notifications(market_id, outcome, winning_option_id) do
    # Get all users who voted in this market
    user_ids =
      from(v in Vote, where: v.market_id == ^market_id, select: v.user_id)
      |> Repo.all()

    market = get_market_with_options!(market_id)
    winning_option = find_option(market.options, winning_option_id)

    message = resolution_message(outcome, market, winning_option)

    # Create notifications for each participant
    for user_id <- user_ids do
      %Notification{}
      |> Notification.changeset(%{
        user_id: user_id,
        market_id: market_id,
        message: message
      })
      |> Repo.insert(on_conflict: :nothing)
    end
  end

  defp find_option(_options, nil), do: nil
  defp find_option(options, option_id), do: Enum.find(options, fn o -> o.id == option_id end)

  defp resolution_message(:majority, market, winning_option) when not is_nil(winning_option) do
    "The market \"#{market.question}\" has resolved. The outcome is: #{winning_option.label}"
  end

  defp resolution_message(:majority, market, _nil) do
    "The market \"#{market.question}\" has resolved."
  end

  defp resolution_message(:tie, market, _winning_option) do
    "The market \"#{market.question}\" has resolved in a tie."
  end

  defp resolution_message(:no_votes, market, _winning_option) do
    "The market \"#{market.question}\" has resolved with no votes cast."
  end

  # --- Notifications ---

  @doc """
  Lists all notifications for a user.
  """
  @spec list_notifications(integer()) :: [Notification.t()]
  def list_notifications(user_id) do
    from(n in Notification,
      where: n.user_id == ^user_id,
      order_by: [desc: n.inserted_at]
    )
    |> preload(:market)
    |> Repo.all()
  end

  @doc """
  Counts unread notifications for a user.
  """
  @spec unread_notification_count(integer()) :: non_neg_integer()
  def unread_notification_count(user_id) do
    from(n in Notification,
      where: n.user_id == ^user_id and n.read == false
    )
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Marks a notification as read.
  """
  @spec mark_notification_read(Notification.t()) :: {:ok, Notification.t()}
  def mark_notification_read(%Notification{} = notification) do
    notification
    |> Notification.mark_read_changeset()
    |> Repo.update!()
    |> then(&{:ok, &1})
  end

  # --- Query Helpers ---

  @doc """
  Gets market with options and votes preloaded.
  Useful for detail pages that need vote counts.
  """
  @spec get_market_detail!(integer()) :: Market.t()
  def get_market_detail!(id) do
    from(m in Market, where: m.id == ^id)
    |> preload(options: ^from(o in MarketOption, order_by: o.position))
    |> Repo.one!()
  end

  @doc """
  Preloads vote counts for a market's options.
  Returns a map of option_id => count.
  """
  @spec preload_vote_counts(Market.t()) :: %{integer() => non_neg_integer()}
  def preload_vote_counts(%Market{id: market_id}) do
    get_vote_counts(market_id)
  end

  # Helper to check for unique constraint violation
  defp has_unique_violation?(changeset, field) do
    case changeset.errors[field] do
      {msg, _} when is_binary(msg) ->
        String.contains?(msg, "has already been taken")

      _ ->
        false
    end
  end
end

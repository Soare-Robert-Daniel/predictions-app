defmodule Predictions.Markets.Market do
  @moduledoc """
  Market schema for prediction markets.

  A market has a question, multiple options, and a voting window.
  It can be in one of three states: upcoming, active, or resolved.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Predictions.Markets.MarketOption
  alias Predictions.Markets.Vote

  @type status :: :upcoming | :active | :closed | :resolved
  @type outcome :: :majority | :tie | :no_votes | nil

  @type t :: %__MODULE__{
          id: integer() | nil,
          question: String.t() | nil,
          voting_start: DateTime.t() | nil,
          voting_end: DateTime.t() | nil,
          outcome: outcome(),
          resolved_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil,
          options: [MarketOption.t()] | Ecto.Association.NotLoaded.t()
        }

  schema "markets" do
    field :question, :string
    field :voting_start, :utc_datetime
    field :voting_end, :utc_datetime
    field :outcome, Ecto.Enum, values: [:majority, :tie, :no_votes]
    field :resolved_at, :utc_datetime

    has_many :options, MarketOption, on_replace: :delete
    has_many :votes, Vote

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a changeset for creating a new market.

  This changeset handles:
  - Question validation (required, non-blank)
  - Voting window validation (end after start)
  - Options validation (at least 2 unique, non-empty labels)
  - Automatic trimming and ordering of options
  """
  def create_changeset(market, attrs) do
    market
    |> cast(attrs, [:question, :voting_start, :voting_end])
    |> validate_required([:question, :voting_start, :voting_end])
    |> validate_question()
    |> validate_voting_window()
    |> cast_options(attrs)
    |> validate_options()
    |> prepare_options()
  end

  @doc """
  Creates a changeset for resolving a market.
  """
  def resolve_changeset(market, outcome) do
    market
    |> change()
    |> put_change(:outcome, outcome)
    |> put_change(:resolved_at, DateTime.utc_now() |> DateTime.truncate(:second))
  end

  defp validate_question(changeset) do
    changeset
    |> validate_length(:question, min: 1, max: 500)
    |> validate_change(:question, fn :question, question ->
      if String.trim(question) == "" do
        [question: "can't be blank"]
      else
        []
      end
    end)
  end

  defp validate_voting_window(changeset) do
    voting_start = get_field(changeset, :voting_start)
    voting_end = get_field(changeset, :voting_end)

    cond do
      is_nil(voting_start) or is_nil(voting_end) ->
        changeset

      DateTime.compare(voting_end, voting_start) != :gt ->
        add_error(changeset, :voting_end, "must be after voting start")

      true ->
        changeset
    end
  end

  defp cast_options(changeset, attrs) do
    options_attrs =
      case attrs do
        %{options: options} when is_list(options) ->
          options
          |> Enum.with_index()
          |> Enum.map(fn {opt, idx} ->
            label = get_label(opt)

            if label && String.trim(label) != "" do
              %{label: String.trim(label), position: idx}
            else
              nil
            end
          end)
          |> Enum.reject(&is_nil/1)

        %{options: options} when is_map(options) ->
          options
          |> Enum.sort_by(fn {idx, _} -> String.to_integer(idx) end)
          |> Enum.map(fn {_idx, opt} ->
            label = get_label(opt)

            if label && String.trim(label) != "" do
              %{label: String.trim(label)}
            else
              nil
            end
          end)
          |> Enum.reject(&is_nil/1)
          |> Enum.with_index()
          |> Enum.map(fn {opt, idx} -> Map.put(opt, :position, idx) end)

        %{"options" => options} when is_list(options) ->
          options
          |> Enum.with_index()
          |> Enum.map(fn {opt, idx} ->
            label = get_label(opt)

            if label && String.trim(label) != "" do
              %{label: String.trim(label), position: idx}
            else
              nil
            end
          end)
          |> Enum.reject(&is_nil/1)

        %{"options" => options} when is_map(options) ->
          options
          |> Enum.sort_by(fn {idx, _} -> String.to_integer(idx) end)
          |> Enum.map(fn {_idx, opt} ->
            label = get_label(opt)

            if label && String.trim(label) != "" do
              %{label: String.trim(label)}
            else
              nil
            end
          end)
          |> Enum.reject(&is_nil/1)
          |> Enum.with_index()
          |> Enum.map(fn {opt, idx} -> Map.put(opt, :position, idx) end)

        _ ->
          []
      end

    put_assoc(changeset, :options, options_attrs)
  end

  defp get_label(%{label: label}), do: label
  defp get_label(%{"label" => label}), do: label
  defp get_label(label) when is_binary(label), do: label
  defp get_label(_), do: nil

  defp validate_options(changeset) do
    options = get_field(changeset, :options) || []

    # Check minimum count
    changeset =
      if length(options) < 2 do
        add_error(changeset, :options, "must have at least 2 options")
      else
        changeset
      end

    # Check for duplicates (case-insensitive)
    labels =
      options
      |> Enum.map(&String.downcase(&1.label))

    unique_labels = Enum.uniq(labels)

    if length(labels) != length(unique_labels) do
      add_error(changeset, :options, "must not have duplicate labels")
    else
      changeset
    end
  end

  defp prepare_options(changeset) do
    # Ensure positions are set correctly in order
    case get_change(changeset, :options) do
      nil ->
        changeset

      options_changesets when is_list(options_changesets) ->
        updated_options =
          options_changesets
          |> Enum.with_index()
          |> Enum.map(fn {opt_cs, idx} ->
            put_change(opt_cs, :position, idx)
          end)

        put_change(changeset, :options, updated_options)
    end
  end

  @doc """
  Returns the status of the market based on current time and resolution state.

  Status transitions:
  - :upcoming - before voting_start
  - :active - between voting_start and voting_end
  - :closed - after voting_end but not yet resolved
  - :resolved - after resolution (outcome set)
  """
  @spec status(t(), DateTime.t()) :: status()
  def status(%__MODULE__{outcome: outcome}, _now) when not is_nil(outcome), do: :resolved

  def status(%__MODULE__{voting_start: voting_start, voting_end: voting_end}, now) do
    cond do
      DateTime.compare(now, voting_start) == :lt -> :upcoming
      DateTime.compare(now, voting_end) != :lt -> :closed
      true -> :active
    end
  end

  @doc """
  Returns true if the market is currently accepting votes.
  """
  @spec voting_active?(t(), DateTime.t()) :: boolean()
  def voting_active?(%__MODULE__{outcome: outcome}, _now) when not is_nil(outcome), do: false

  def voting_active?(%__MODULE__{voting_start: voting_start, voting_end: voting_end}, now) do
    DateTime.compare(now, voting_start) != :lt and
      DateTime.compare(now, voting_end) == :lt
  end

  @doc """
  Returns true if the market has ended and can be resolved.
  """
  @spec can_resolve?(t(), DateTime.t()) :: boolean()
  def can_resolve?(%__MODULE__{outcome: outcome}, _now) when not is_nil(outcome), do: false

  def can_resolve?(%__MODULE__{voting_end: voting_end}, now) do
    DateTime.compare(now, voting_end) != :lt
  end
end

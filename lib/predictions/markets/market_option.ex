defmodule Predictions.Markets.MarketOption do
  @moduledoc """
  Market option schema for prediction market options.

  Each market has multiple options that users can vote on.
  Options are ordered by position.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Predictions.Markets.Market
  alias Predictions.Markets.Vote

  @type t :: %__MODULE__{
          id: integer() | nil,
          label: String.t() | nil,
          position: integer() | nil,
          market_id: integer() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil,
          market: Market.t() | Ecto.Association.NotLoaded.t(),
          votes: [Vote.t()] | Ecto.Association.NotLoaded.t()
        }

  schema "market_options" do
    field :label, :string
    field :position, :integer, default: 0

    belongs_to :market, Market
    has_many :votes, Vote

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a changeset for a market option.
  """
  def changeset(option, attrs) do
    option
    |> cast(attrs, [:label, :position, :market_id])
    |> validate_required([:label, :market_id])
    |> validate_length(:label, min: 1, max: 200)
    |> foreign_key_constraint(:market_id)
  end
end

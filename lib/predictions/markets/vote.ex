defmodule Predictions.Markets.Vote do
  @moduledoc """
  Vote schema for user votes on prediction markets.

  Each user can only vote once per market.
  This is enforced by a unique constraint at the database level.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Predictions.Accounts.User
  alias Predictions.Markets.Market
  alias Predictions.Markets.MarketOption

  @type t :: %__MODULE__{
          id: integer() | nil,
          user_id: integer() | nil,
          market_id: integer() | nil,
          market_option_id: integer() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil,
          user: User.t() | Ecto.Association.NotLoaded.t(),
          market: Market.t() | Ecto.Association.NotLoaded.t(),
          market_option: MarketOption.t() | Ecto.Association.NotLoaded.t()
        }

  schema "votes" do
    belongs_to :user, User
    belongs_to :market, Market
    belongs_to :market_option, MarketOption

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a changeset for a vote.
  """
  def changeset(vote, attrs) do
    vote
    |> cast(attrs, [:user_id, :market_id, :market_option_id])
    |> validate_required([:user_id, :market_id, :market_option_id])
    |> unique_constraint([:user_id, :market_id], name: :votes_user_id_market_id_index)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:market_id)
    |> foreign_key_constraint(:market_option_id)
    |> validate_option_belongs_to_market()
  end

  defp validate_option_belongs_to_market(changeset) do
    # This validation will be handled at the context level
    # where we can query to verify the option belongs to the market
    changeset
  end
end

defmodule Predictions.Markets.Notification do
  @moduledoc """
  Notification schema for user notifications.

  Currently used for market resolution notifications.
  Each user receives one notification per market resolution.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Predictions.Accounts.User
  alias Predictions.Markets.Market

  @type t :: %__MODULE__{
          id: integer() | nil,
          user_id: integer() | nil,
          market_id: integer() | nil,
          message: String.t() | nil,
          read: boolean(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil,
          user: User.t() | Ecto.Association.NotLoaded.t(),
          market: Market.t() | Ecto.Association.NotLoaded.t()
        }

  schema "notifications" do
    belongs_to :user, User
    belongs_to :market, Market

    field :message, :string
    field :read, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a changeset for a notification.
  """
  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:user_id, :market_id, :message, :read])
    |> validate_required([:user_id, :market_id, :message])
    |> unique_constraint([:user_id, :market_id], name: :notifications_user_id_market_id_index)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:market_id)
  end

  @doc """
  Creates a changeset for marking a notification as read.
  """
  def mark_read_changeset(notification) do
    change(notification, read: true)
  end
end

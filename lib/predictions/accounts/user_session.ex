defmodule Predictions.Accounts.UserSession do
  @moduledoc """
  User session schema for tracking active sessions.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          user_id: integer() | nil,
          token: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "user_sessions" do
    belongs_to :user, Predictions.Accounts.User
    field :token, :string

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a session changeset.
  """
  def changeset(session, attrs) do
    session
    |> cast(attrs, [:user_id, :token])
    |> validate_required([:user_id, :token])
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Generates a secure random token.
  """
  def generate_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end
end

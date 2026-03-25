defmodule Predictions.Accounts.User do
  @moduledoc """
  User schema with role-based access control.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          email: String.t() | nil,
          hashed_password: String.t() | nil,
          role: :admin | :user,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true
    field :hashed_password, :string
    field :role, Ecto.Enum, values: [:admin, :user], default: :user

    timestamps(type: :utc_datetime)
  end

  @doc """
  A user changeset for registration.

  This changeset handles password hashing and validation.
  """
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password, :role])
    |> validate_email()
    |> validate_password()
    |> put_hashed_password()
  end

  defp validate_email(changeset) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/,
      message: "must have the @ sign and no spaces"
    )
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, Predictions.Repo)
    |> unique_constraint(:email)
  end

  defp validate_password(changeset) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 8, max: 72)
  end

  defp put_hashed_password(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{password: password}} ->
        put_change(changeset, :hashed_password, Bcrypt.hash_pwd_salt(password))

      _ ->
        changeset
    end
  end

  @doc """
  Verifies the password against the hashed password.
  """
  def valid_password?(%__MODULE__{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and is_binary(password) do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  @doc """
  Returns true if the user is an admin.
  """
  def admin?(%__MODULE__{role: :admin}), do: true
  def admin?(_), do: false
end

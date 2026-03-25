defmodule Predictions.Accounts do
  @moduledoc """
  The Accounts context module for user authentication and management.
  """

  import Ecto.Query, warn: false
  alias Predictions.Repo
  alias Predictions.Accounts.User

  @doc """
  Returns the list of users.
  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.
  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Gets a user by ID. Returns nil if not found.
  """
  def get_user(id) when is_integer(id) do
    Repo.get(User, id)
  end

  def get_user(_), do: nil

  @doc """
  Gets a user by email.
  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  def get_user_by_email(_), do: nil

  @doc """
  Creates a user.
  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Registers a new user with default role.
  """
  def register_user(attrs \\ %{}) do
    attrs = Map.put_new(attrs, :role, :user)
    create_user(attrs)
  end

  @doc """
  Creates an admin user.
  """
  def create_admin_user(attrs \\ %{}) do
    attrs = Map.put(attrs, :role, :admin)
    create_user(attrs)
  end

  @doc """
  Updates a user.
  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.registration_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user.
  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Authenticates a user by email and password.
  Returns {:ok, user} on success or {:error, :unauthorized} on failure.
  """
  def authenticate_user(email, password) when is_binary(email) and is_binary(password) do
    case get_user_by_email(email) do
      %User{} = user ->
        if User.valid_password?(user, password) do
          {:ok, user}
        else
          {:error, :unauthorized}
        end

      nil ->
        Bcrypt.no_user_verify()
        {:error, :unauthorized}
    end
  end

  def authenticate_user(_, _), do: {:error, :unauthorized}

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.
  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs)
  end

  # Session management

  alias Predictions.Accounts.UserSession

  @doc """
  Creates a new session for the given user.
  Returns the session token.
  """
  def create_session(%User{id: user_id}) do
    token = UserSession.generate_token()

    %UserSession{}
    |> UserSession.changeset(%{user_id: user_id, token: token})
    |> Repo.insert()
    |> case do
      {:ok, _session} -> token
      {:error, _changeset} -> nil
    end
  end

  @doc """
  Gets a user by session token.
  Returns nil if the session doesn't exist or is invalid.
  """
  def get_user_by_session_token(token) when is_binary(token) do
    from(s in UserSession, where: s.token == ^token, preload: [:user])
    |> Repo.one()
    |> case do
      %UserSession{user: user} -> user
      nil -> nil
    end
  end

  def get_user_by_session_token(_), do: nil

  @doc """
  Deletes a session by token.
  """
  def delete_session_token(token) when is_binary(token) do
    from(s in UserSession, where: s.token == ^token)
    |> Repo.delete_all()

    :ok
  end

  def delete_session_token(_), do: :ok
end

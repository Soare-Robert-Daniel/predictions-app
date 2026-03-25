defmodule PredictionsWeb.Plugs.Auth do
  @moduledoc """
  Authentication plugs for protecting routes.
  """

  import Plug.Conn
  import Phoenix.Controller
  use PredictionsWeb, :verified_routes

  alias Predictions.Accounts

  @session_key :user_token

  @doc """
  Authenticates a user from the session token.
  Stores the user in conn.assigns[:current_user].
  """
  def fetch_current_user(conn, _opts) do
    user_token = get_session(conn, @session_key)
    user = user_token && Accounts.get_user_by_session_token(user_token)

    assign(conn, :current_user, user)
  end

  @doc """
  Requires a user to be authenticated.
  Redirects to sign-in page if not authenticated.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> redirect(to: ~p"/sign-in")
      |> halt()
    end
  end

  @doc """
  Requires the user to be an admin.
  Redirects normal users to the user dashboard and guests to sign-in.
  """
  def require_admin_user(conn, _opts) do
    user = conn.assigns[:current_user]

    cond do
      is_nil(user) ->
        conn
        |> put_flash(:error, "You must log in to access this page.")
        |> redirect(to: ~p"/sign-in")
        |> halt()

      Predictions.Accounts.User.admin?(user) ->
        conn

      true ->
        conn
        |> put_flash(:error, "You do not have permission to access this page.")
        |> redirect(to: ~p"/dashboard")
        |> halt()
    end
  end

  @doc """
  Logs the user in by storing the session token.
  """
  def login(conn, user) do
    token = Accounts.create_session(user)

    conn
    |> put_session(@session_key, token)
    |> configure_session(renew: true)
  end

  @doc """
  Logs the user out by deleting the session token.
  """
  def logout(conn) do
    user_token = get_session(conn, @session_key)
    user_token && Accounts.delete_session_token(user_token)

    conn
    |> delete_session(@session_key)
    |> configure_session(drop: true)
  end

  # LiveView on_mount callbacks

  def on_mount(:ensure_authenticated, _params, session, socket) do
    # Handle both atom and string keys for session
    user_token = session[:user_token] || session["user_token"]
    user = user_token && Accounts.get_user_by_session_token(user_token)

    socket =
      socket
      |> Phoenix.Component.assign_new(:current_user, fn -> user end)
      |> Phoenix.Component.assign_new(:current_scope, fn -> user end)

    if user do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/sign-in")

      {:halt, socket}
    end
  end

  def on_mount(:ensure_admin, _params, session, socket) do
    # Handle both atom and string keys for session
    user_token = session[:user_token] || session["user_token"]
    user = user_token && Accounts.get_user_by_session_token(user_token)

    socket =
      socket
      |> Phoenix.Component.assign_new(:current_user, fn -> user end)
      |> Phoenix.Component.assign_new(:current_scope, fn -> user end)

    cond do
      is_nil(user) ->
        socket =
          socket
          |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
          |> Phoenix.LiveView.redirect(to: ~p"/sign-in")

        {:halt, socket}

      Predictions.Accounts.User.admin?(user) ->
        {:cont, socket}

      true ->
        socket =
          socket
          |> Phoenix.LiveView.put_flash(:error, "You do not have permission to access this page.")
          |> Phoenix.LiveView.redirect(to: ~p"/dashboard")

        {:halt, socket}
    end
  end
end

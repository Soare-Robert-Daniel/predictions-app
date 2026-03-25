defmodule PredictionsWeb.SessionController do
  @moduledoc """
  Controller for session management (sign-in and sign-out).
  """

  use PredictionsWeb, :controller

  import PredictionsWeb.Plugs.Auth, only: [login: 2, logout: 1]
  import Phoenix.Component, only: [to_form: 2]

  alias Predictions.Accounts

  def new(conn, _params) do
    render(conn, :new, form: to_form(%{}, as: :session))
  end

  def create(conn, %{"session" => %{"email" => email, "password" => password}}) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        conn
        |> login(user)
        |> redirect_after_login(user)

      {:error, :unauthorized} ->
        conn
        |> put_flash(:error, "Invalid email or password.")
        |> render(:new, form: to_form(%{"email" => email}, as: :session))
    end
  end

  def create(conn, _params) do
    conn
    |> put_flash(:error, "Invalid email or password.")
    |> render(:new, form: to_form(%{}, as: :session))
  end

  def delete(conn, _params) do
    conn
    |> logout()
    |> put_flash(:info, "You have been signed out.")
    |> redirect(to: ~p"/")
  end

  defp redirect_after_login(conn, user) do
    if Predictions.Accounts.User.admin?(user) do
      redirect(conn, to: ~p"/admin")
    else
      redirect(conn, to: ~p"/dashboard")
    end
  end
end

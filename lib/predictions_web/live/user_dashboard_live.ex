defmodule PredictionsWeb.UserDashboardLive do
  @moduledoc """
  User dashboard - the protected area for signed-in normal users.
  """

  use PredictionsWeb, :live_view

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Welcome to your dashboard
        <:subtitle>
          Browse and vote on prediction markets.
        </:subtitle>
      </.header>

      <div class="mt-8">
        <p class="text-base-content/70">
          Signed in as: <strong>{@current_user.email}</strong>
        </p>
        <p class="mt-4 text-base-content/70">
          Prediction markets will appear here once they are created by administrators.
        </p>
      </div>

      <div class="mt-8">
        <.link href={~p"/sign-out"} method="delete" class="btn btn-outline btn-error">
          Sign out
        </.link>
      </div>
    </Layouts.app>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end

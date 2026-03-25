defmodule PredictionsWeb.AdminDashboardLive do
  @moduledoc """
  Admin dashboard - the protected area for signed-in administrators.
  """

  use PredictionsWeb, :live_view

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Admin Dashboard
        <:subtitle>
          Create and manage prediction markets.
        </:subtitle>
      </.header>

      <div class="mt-8">
        <p class="text-base-content/70">
          Signed in as admin: <strong>{@current_user.email}</strong>
        </p>
        <p class="mt-4 text-base-content/70">
          Use this area to create prediction markets and manage the application.
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

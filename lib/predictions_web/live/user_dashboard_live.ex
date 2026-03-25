defmodule PredictionsWeb.UserDashboardLive do
  @moduledoc """
  User dashboard - the protected area for signed-in normal users.
  """

  use PredictionsWeb, :live_view

  alias Predictions.Markets

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Welcome to your dashboard
        <:subtitle>
          Browse and vote on prediction markets.
        </:subtitle>
      </.header>

      <div class="mt-4" data-notification-count={@notification_count}>
        <%= if @notification_count > 0 do %>
          <.link navigate={~p"/notifications"} class="btn btn-info btn-outline">
            <.icon name="hero-bell" class="size-4" />
            {@notification_count} new notification{if @notification_count > 1, do: "s", else: ""}
          </.link>
        <% else %>
          <.link navigate={~p"/notifications"} class="btn btn-ghost btn-outline">
            <.icon name="hero-bell" class="size-4" /> Notifications
          </.link>
        <% end %>
      </div>

      <div class="mt-8">
        <p class="text-base-content/70">
          Signed in as: <strong>{@current_user.email}</strong>
        </p>
        <p class="mt-4 text-base-content/70">
          Prediction markets will appear here once they are created by administrators.
        </p>
      </div>

      <div class="mt-8">
        <.link navigate={~p"/markets"} class="btn btn-primary mr-2">
          Browse Markets
        </.link>
        <.link href={~p"/sign-out"} method="delete" class="btn btn-outline btn-error">
          Sign out
        </.link>
      </div>
    </Layouts.app>
    """
  end

  def mount(_params, _session, socket) do
    current_user = socket.assigns[:current_user]

    notification_count =
      if current_user do
        Markets.unread_notification_count(current_user.id)
      else
        0
      end

    {:ok, assign(socket, :notification_count, notification_count)}
  end
end

defmodule PredictionsWeb.NotificationInboxLive do
  @moduledoc """
  LiveView for displaying a user's notification inbox.

  Shows all notifications for the signed-in user, including:
  - Market resolution notifications
  - Deep-links to the resolved market pages
  - Unread notification indicators
  """

  use PredictionsWeb, :live_view

  alias Predictions.Markets

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Notifications
        <:subtitle>
          <%= if @unread_count > 0 do %>
            You have {@unread_count} unread notification{if @unread_count > 1, do: "s", else: ""}
          <% else %>
            All caught up!
          <% end %>
        </:subtitle>
      </.header>

      <div class="mt-6" data-notification-inbox>
        <div :if={@notifications == []} class="text-center py-12">
          <.icon name="hero-bell-slash" class="size-12 text-base-content/30 mb-4" />
          <p class="text-base-content/70">No notifications yet.</p>
          <p class="text-sm text-base-content/50 mt-2">
            You'll receive notifications when markets you voted on are resolved.
          </p>
        </div>

        <div :if={@notifications != []} class="grid gap-4">
          <.notification_card
            :for={notification <- @notifications}
            notification={notification}
            current_user={@current_user}
          />
        </div>
      </div>

      <div class="mt-4">
        <.link navigate={~p"/markets"} class="btn btn-ghost">
          <.icon name="hero-arrow-left" class="size-4" /> Back to Markets
        </.link>
      </div>
    </Layouts.app>
    """
  end

  defp notification_card(assigns) do
    ~H"""
    <.link
      navigate={~p"/markets/#{@notification.market_id}"}
      class="block card bg-base-200 hover:bg-base-300 transition-colors"
      data-notification-market-id={@notification.market_id}
    >
      <div class="card-body">
        <div class="flex items-start justify-between gap-4">
          <div class="flex-1">
            <div class="flex items-center gap-2">
              <.icon
                :if={not @notification.read}
                name="hero-circle"
                class="size-3 text-primary"
              />
              <h3 class="card-title text-base">
                {@notification.market.question}
              </h3>
            </div>
            <p class="text-sm text-base-content/70 mt-2">
              {@notification.message}
            </p>
            <p class="text-xs text-base-content/50 mt-2">
              {format_datetime(@notification.inserted_at)}
            </p>
          </div>

          <div class="flex-none">
            <.outcome_badge market={@notification.market} />
          </div>
        </div>
      </div>
    </.link>
    """
  end

  defp outcome_badge(assigns) do
    ~H"""
    <div class={[
      "badge badge-sm font-medium",
      @market.outcome == :majority && "badge-success",
      @market.outcome == :tie && "badge-warning",
      @market.outcome == :no_votes && "badge-neutral"
    ]}>
      <%= case @market.outcome do %>
        <% :majority -> %>
          <%= if @market.winning_option do %>
            {@market.winning_option.label}
          <% else %>
            Winner
          <% end %>
        <% :tie -> %>
          Tie
        <% :no_votes -> %>
          No votes
      <% end %>
    </div>
    """
  end

  defp format_datetime(datetime) do
    datetime
    |> DateTime.to_naive()
    |> NaiveDateTime.to_string()
  end

  def mount(_params, _session, socket) do
    current_user = socket.assigns[:current_user]

    notifications = Markets.list_notifications(current_user.id)
    unread_count = Markets.unread_notification_count(current_user.id)

    {:ok,
     socket
     |> assign(:notifications, notifications)
     |> assign(:unread_count, unread_count)
     |> assign(:current_user, current_user)}
  end
end

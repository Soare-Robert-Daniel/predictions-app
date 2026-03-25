defmodule PredictionsWeb.MarketDetailLive do
  @moduledoc """
  LiveView for displaying market details to signed-in users.

  Shows the market question, options with vote counts, and state markers.
  """

  use PredictionsWeb, :live_view

  alias Predictions.Markets

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@market.question}
        <:subtitle>
          <.market_state_badge status={@market.status} />
        </:subtitle>
      </.header>

      <div class="mt-6">
        <div class="card bg-base-200">
          <div class="card-body">
            <h3 class="card-title text-lg mb-4">Options</h3>

            <div class="grid gap-3">
              <.option_card
                :for={{option, vote_count} <- @options_with_counts}
                option={option}
                vote_count={vote_count}
              />
            </div>

            <div class="mt-6 text-sm text-base-content/60">
              <p>
                <strong>Voting Period:</strong>
              </p>
              <p>
                {format_datetime(@market.voting_start)} to {format_datetime(@market.voting_end)}
              </p>
            </div>
          </div>
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

  defp option_card(assigns) do
    ~H"""
    <div
      class="flex items-center justify-between p-4 rounded-lg bg-base-100 border border-base-300"
      data-option-id={@option.id}
      data-vote-count={@vote_count}
    >
      <div class="flex items-center gap-3">
        <span class="font-medium">{@option.label}</span>
      </div>
      <div class="flex items-center gap-2">
        <span class="text-sm text-base-content/60">Votes:</span>
        <span class="font-bold text-lg">{@vote_count}</span>
      </div>
    </div>
    """
  end

  defp market_state_badge(assigns) do
    ~H"""
    <div
      class={[
        "badge badge-sm font-medium",
        @status == :upcoming && "badge-info",
        @status == :active && "badge-success",
        @status == :resolved && "badge-neutral"
      ]}
      data-market-state={@status}
    >
      {format_status(@status)}
    </div>
    """
  end

  defp format_status(:upcoming), do: "Upcoming"
  defp format_status(:active), do: "Active"
  defp format_status(:resolved), do: "Resolved"

  defp format_datetime(datetime) do
    datetime
    |> DateTime.to_naive()
    |> NaiveDateTime.to_string()
  end

  def mount(%{"id" => id}, _session, socket) do
    market = Markets.get_market_with_options!(id)
    status = Markets.market_status(market)

    options_with_counts = Markets.list_options_with_vote_counts(market.id)

    market_with_status = Map.put(market, :status, status)

    socket =
      socket
      |> assign(:market, market_with_status)
      |> assign(:options_with_counts, options_with_counts)

    {:ok, socket}
  end
end

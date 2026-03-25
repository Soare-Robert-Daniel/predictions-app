defmodule PredictionsWeb.MarketListLive do
  @moduledoc """
  LiveView for displaying the list of prediction markets to signed-in users.
  """

  use PredictionsWeb, :live_view

  alias Predictions.Markets

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Markets
        <:subtitle>
          Browse prediction markets and cast your vote.
        </:subtitle>
      </.header>

      <div class="mt-6">
        <div :if={@markets == []} class="text-center py-12">
          <p class="text-base-content/70">No markets available yet.</p>
          <p class="text-sm text-base-content/50 mt-2">
            Markets will appear here once they are created by administrators.
          </p>
        </div>

        <div :if={@markets != []} class="grid gap-4">
          <.market_card :for={market <- @markets} market={market} />
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp market_card(assigns) do
    ~H"""
    <.link
      navigate={~p"/markets/#{@market.id}"}
      class="block card bg-base-200 hover:bg-base-300 transition-colors"
    >
      <div class="card-body">
        <div class="flex items-start justify-between gap-4">
          <h3 class="card-title text-base">{@market.question}</h3>
          <.market_state_badge status={@market.status} />
        </div>

        <div class="flex flex-wrap gap-2 mt-2">
          <span
            :for={option <- @market.options}
            class={[
              "badge badge-sm",
              is_winner?(option, @market) && "badge-success",
              !is_winner?(option, @market) && "badge-outline"
            ]}
          >
            {option.label}
          </span>
        </div>

        <div class="flex items-center gap-4 mt-3">
          <div class="text-sm text-base-content/60">
            <span>
              Voting: {format_datetime(@market.voting_start)} - {format_datetime(@market.voting_end)}
            </span>
          </div>

          <div :if={@market.status == :resolved and @market.outcome} class="text-sm">
            <.outcome_indicator outcome={@market.outcome} market={@market} />
          </div>
        </div>
      </div>
    </.link>
    """
  end

  defp outcome_indicator(assigns) do
    ~H"""
    <span class="text-base-content/70" data-outcome={@outcome}>
      <%= case @outcome do %>
        <% :majority -> %>
          <span class="text-success">Winner: {@market.winning_option.label}</span>
        <% :tie -> %>
          <span class="text-warning">Tie</span>
        <% :no_votes -> %>
          <span class="text-base-content/50">No votes</span>
      <% end %>
    </span>
    """
  end

  defp is_winner?(option, market) do
    market.outcome == :majority and market.winning_option_id == option.id
  end

  defp market_state_badge(assigns) do
    ~H"""
    <div
      class={[
        "badge badge-sm font-medium",
        @status == :upcoming && "badge-info",
        @status == :active && "badge-success",
        @status == :closed && "badge-warning",
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
  defp format_status(:closed), do: "Closed"
  defp format_status(:resolved), do: "Resolved"

  defp format_datetime(datetime) do
    datetime
    |> DateTime.to_naive()
    |> NaiveDateTime.to_string()
  end

  def mount(_params, _session, socket) do
    markets = Markets.list_markets_with_options()

    markets =
      Enum.map(markets, fn market ->
        Map.put(market, :status, Markets.market_status(market))
      end)

    {:ok, assign(socket, :markets, markets)}
  end
end

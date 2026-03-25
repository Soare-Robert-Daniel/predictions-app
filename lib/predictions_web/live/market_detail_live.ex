defmodule PredictionsWeb.MarketDetailLive do
  @moduledoc """
  LiveView for displaying market details to signed-in users.

  Shows the market question, options with vote counts, and state markers.
  Allows eligible users to cast votes on active markets.
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
                is_winner={is_winner?(option, @market)}
              />
            </div>

            <.resolved_outcome_section :if={@market.status == :resolved} market={@market} />
            
    <!-- Voting Section -->
            <.voting_section
              market={@market}
              current_user={@current_user}
              user_vote={@user_vote}
              user_vote_option_label={@user_vote_option_label}
              can_vote={@can_vote}
              options={@market.options}
              form={@vote_form}
              market_status={@market.status}
            />

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
      class={[
        "flex items-center justify-between p-4 rounded-lg border",
        @is_winner && "bg-success/10 border-success",
        !@is_winner && "bg-base-100 border-base-300"
      ]}
      data-option-id={@option.id}
      data-vote-count={@vote_count}
    >
      <div class="flex items-center gap-3">
        <span class="font-medium">{@option.label}</span>
        <%= if @is_winner do %>
          <span class="badge badge-success badge-sm">Winner</span>
        <% end %>
      </div>
      <div class="flex items-center gap-2">
        <span class="text-sm text-base-content/60">Votes:</span>
        <span class="font-bold text-lg">{@vote_count}</span>
      </div>
    </div>
    """
  end

  defp voting_section(assigns) do
    ~H"""
    <div class="mt-6 pt-6 border-t border-base-300">
      <%= cond do %>
        <% @current_user.role == :admin -> %>
          <div class="alert alert-info">
            <.icon name="hero-information-circle" class="size-5" />
            <div>
              <p class="font-semibold">Admin Role</p>
              <p class="text-sm">As an admin, you cannot vote on markets.</p>
            </div>
          </div>
        <% @user_vote != nil -> %>
          <div class="alert alert-success" data-already-voted>
            <.icon name="hero-check-circle" class="size-5" />
            <div>
              <p class="font-semibold">Vote Recorded</p>
              <p class="text-sm">
                You voted for: <strong>{@user_vote_option_label}</strong>
              </p>
            </div>
          </div>
        <% @market_status == :upcoming -> %>
          <div class="alert alert-warning" data-voting-unavailable>
            <.icon name="hero-clock" class="size-5" />
            <div>
              <p class="font-semibold">Voting Not Available</p>
              <p class="text-sm">Voting has not started yet.</p>
            </div>
          </div>
        <% @market_status == :closed -> %>
          <div class="alert alert-warning" data-voting-unavailable>
            <.icon name="hero-clock" class="size-5" />
            <div>
              <p class="font-semibold">Voting Not Available</p>
              <p class="text-sm">Voting has ended for this market.</p>
            </div>
          </div>
        <% @market_status == :resolved -> %>
          <div class="alert alert-info" data-voting-unavailable>
            <.icon name="hero-information-circle" class="size-5" />
            <div>
              <p class="font-semibold">Market Resolved</p>
              <p class="text-sm">This market has been resolved.</p>
            </div>
          </div>
        <% true -> %>
          <.form for={@form} id="vote-form" phx-submit="submit_vote">
            <h4 class="font-semibold mb-3">Cast Your Vote</h4>
            <div class="space-y-2 mb-4">
              <%= for option <- @options do %>
                <label class="flex items-center gap-3 p-3 rounded-lg bg-base-100 border border-base-300 cursor-pointer hover:bg-base-200 transition-colors">
                  <input
                    type="radio"
                    name="vote[option_id]"
                    value={option.id}
                    class="radio radio-primary"
                    required
                  />
                  <span class="font-medium">{option.label}</span>
                </label>
              <% end %>
            </div>
            <.button type="submit" class="btn btn-primary w-full">
              Submit Vote
            </.button>
          </.form>
      <% end %>
    </div>
    """
  end

  defp resolved_outcome_section(assigns) do
    ~H"""
    <div
      class="mt-6 pt-6 border-t border-base-300"
      data-resolved-outcome
      data-outcome={@market.outcome}
    >
      <h3 class="card-title text-lg mb-4">Outcome</h3>

      <div class="alert alert-neutral">
        <.icon name="hero-trophy" class="size-5" />
        <div>
          <%= case @market.outcome do %>
            <% :majority -> %>
              <p class="font-semibold">Winner Determined</p>
              <p class="text-sm">
                The outcome is: <strong>{@market.winning_option.label}</strong>
              </p>
            <% :tie -> %>
              <p class="font-semibold">Tie Result</p>
              <p class="text-sm">
                Multiple options tied for the highest votes. No single winner was determined.
              </p>
            <% :no_votes -> %>
              <p class="font-semibold">No Votes Cast</p>
              <p class="text-sm">
                No votes were cast for this market. No outcome was determined.
              </p>
          <% end %>
        </div>
      </div>
    </div>
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

  def mount(%{"id" => id}, _session, socket) do
    market = Markets.get_market_with_options!(id)
    status = Markets.market_status(market)
    options_with_counts = Markets.list_options_with_vote_counts(market.id)

    current_user = socket.assigns[:current_user]

    # Check if user has already voted
    user_vote =
      if current_user do
        Markets.get_user_vote(current_user.id, market.id)
      else
        nil
      end

    # Determine if user can vote
    can_vote =
      current_user != nil and
        current_user.role != :admin and
        status == :active and
        user_vote == nil

    market_with_status = Map.put(market, :status, status)

    socket =
      socket
      |> assign(:market, market_with_status)
      |> assign(:options_with_counts, options_with_counts)
      |> assign(:current_user, current_user)
      |> assign(:user_vote, user_vote)
      |> assign(:user_vote_option_label, get_vote_option_label(user_vote, market))
      |> assign(:can_vote, can_vote)
      |> assign(:vote_form, to_form(%{}, as: :vote))

    {:ok, socket}
  end

  defp get_vote_option_label(nil, _market), do: nil

  defp get_vote_option_label(vote, market) do
    option = Enum.find(market.options, fn o -> o.id == vote.market_option_id end)
    if option, do: option.label, else: "Unknown"
  end

  def handle_event("submit_vote", %{"vote" => %{"option_id" => option_id_str}}, socket) do
    current_user = socket.assigns[:current_user]
    market = socket.assigns[:market]

    # Parse option ID
    option_id =
      case Integer.parse(option_id_str) do
        {id, ""} -> id
        _ -> nil
      end

    # Validate option exists and belongs to market
    option =
      Enum.find(market.options, fn o -> o.id == option_id end)

    cond do
      is_nil(option_id) ->
        {:noreply, socket |> put_flash(:error, "Please select an option to vote.")}

      is_nil(option) ->
        {:noreply, socket |> put_flash(:error, "Invalid option selected. Please try again.")}

      current_user.role == :admin ->
        {:noreply, socket |> put_flash(:error, "Admins cannot vote on markets.")}

      true ->
        case Markets.cast_vote(current_user, market.id, option_id) do
          {:ok, _vote} ->
            # Refresh data
            options_with_counts = Markets.list_options_with_vote_counts(market.id)
            user_vote = Markets.get_user_vote(current_user.id, market.id)

            socket =
              socket
              |> assign(:options_with_counts, options_with_counts)
              |> assign(:user_vote, user_vote)
              |> assign(:user_vote_option_label, get_vote_option_label(user_vote, market))
              |> assign(:can_vote, false)
              |> put_flash(:info, "Your vote has been recorded!")

            {:noreply, socket}

          {:error, :already_voted} ->
            # Refresh and show already voted state
            user_vote = Markets.get_user_vote(current_user.id, market.id)

            socket =
              socket
              |> assign(:user_vote, user_vote)
              |> assign(:user_vote_option_label, get_vote_option_label(user_vote, market))
              |> assign(:can_vote, false)
              |> put_flash(:error, "You have already voted on this market.")

            {:noreply, socket}

          {:error, :market_inactive} ->
            {:noreply,
             socket |> put_flash(:error, "Voting is no longer available for this market.")}

          {:error, :invalid_option} ->
            {:noreply,
             socket |> put_flash(:error, "Invalid option. Please select a valid option.")}

          {:error, :admin_cannot_vote} ->
            {:noreply, socket |> put_flash(:error, "Admins cannot vote on markets.")}

          {:error, _changeset} ->
            {:noreply, socket |> put_flash(:error, "Failed to submit vote. Please try again.")}
        end
    end
  end

  # Handle empty or invalid form submissions
  def handle_event("submit_vote", _params, socket) do
    {:noreply, socket |> put_flash(:error, "Please select an option to vote.")}
  end
end

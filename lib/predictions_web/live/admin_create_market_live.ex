defmodule PredictionsWeb.AdminCreateMarketLive do
  @moduledoc """
  Admin LiveView for creating prediction markets.
  """

  use PredictionsWeb, :live_view

  alias Predictions.Markets
  alias Predictions.Markets.Market

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Create Market
        <:subtitle>
          Add a new prediction market for users to vote on.
        </:subtitle>
      </.header>

      <div class="mt-6">
        <.form for={@form} id="create-market-form" phx-change="validate" phx-submit="save">
          <.input
            field={@form[:question]}
            type="text"
            label="Question"
            placeholder="Enter the prediction question"
            required
          />

          <div class="mt-6">
            <h3 class="text-sm font-semibold mb-2">Options</h3>
            <p class="text-sm text-base-content/70 mb-3">
              Add at least 2 options. Blank options will be ignored.
            </p>

            <div id="options-container">
              <input
                :for={{option, idx} <- Enum.with_index(@options)}
                type="text"
                name={"market[options][#{idx}][label]"}
                id={"market_options_#{idx}_label"}
                value={option.label}
                placeholder="Option label"
                class="w-full input mb-2"
              />
            </div>

            <button
              type="button"
              phx-click="add_option"
              class="btn btn-outline btn-sm mt-2"
            >
              <.icon name="hero-plus" class="size-4" /> Add Option
            </button>

            <p :if={@options_error} class="mt-1.5 flex gap-2 items-center text-sm text-error">
              <.icon name="hero-exclamation-circle" class="size-5" />
              {@options_error}
            </p>
          </div>

          <div class="mt-6">
            <h3 class="text-sm font-semibold mb-2">Voting Window</h3>

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <.input
                field={@form[:voting_start]}
                type="datetime-local"
                label="Voting Start"
              />
              <.input
                field={@form[:voting_end]}
                type="datetime-local"
                label="Voting End"
              />
            </div>

            <p :if={@voting_window_error} class="mt-1.5 flex gap-2 items-center text-sm text-error">
              <.icon name="hero-exclamation-circle" class="size-5" />
              {@voting_window_error}
            </p>
          </div>

          <div class="mt-6 flex gap-3">
            <.button type="submit" variant="primary">Create Market</.button>
            <.link href={~p"/admin"} class="btn btn-ghost">Cancel</.link>
          </div>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:options, [%{label: ""}, %{label: ""}, %{label: ""}, %{label: ""}])
      |> assign(:options_error, nil)
      |> assign(:voting_window_error, nil)
      |> assign_form(%{})

    {:ok, socket}
  end

  def handle_event("validate", %{"market" => market_params}, socket) do
    # Update options from params
    options = parse_options_from_params(market_params)

    socket =
      socket
      |> assign(:options, options)
      |> assign_form(market_params)

    {:noreply, socket}
  end

  def handle_event("add_option", _params, socket) do
    options = socket.assigns.options ++ [%{label: ""}]
    {:noreply, assign(socket, :options, options)}
  end

  def handle_event("save", %{"market" => market_params}, socket) do
    # Parse datetime fields
    market_params = parse_datetime_params(market_params)

    case Markets.create_market(market_params) do
      {:ok, _market} ->
        {:noreply,
         socket
         |> put_flash(:info, "Market created successfully!")
         |> push_navigate(to: ~p"/admin")}

      {:error, changeset} ->
        # Extract specific errors for display
        options_error = extract_options_error(changeset)
        voting_window_error = extract_voting_window_error(changeset)

        socket =
          socket
          |> assign(:options_error, options_error)
          |> assign(:voting_window_error, voting_window_error)
          |> assign_form_with_errors(market_params, changeset)

        {:noreply, socket}
    end
  end

  # Helper functions

  defp assign_form(socket, market_params) do
    form =
      Market.create_changeset(%Market{}, market_params)
      |> Phoenix.Component.to_form(as: :market)

    assign(socket, :form, form)
  end

  defp assign_form_with_errors(socket, market_params, changeset) do
    # Preserve the options that were submitted
    options = parse_options_from_params(market_params)

    form = Phoenix.Component.to_form(changeset, as: :market)

    socket
    |> assign(:form, form)
    |> assign(:options, options)
  end

  defp parse_options_from_params(market_params) do
    case Map.get(market_params, "options", %{}) do
      options when is_map(options) ->
        options
        |> Enum.sort_by(fn {idx, _} -> String.to_integer(idx) end)
        |> Enum.map(fn {_idx, %{"label" => label}} -> %{label: label || ""} end)

      options when is_list(options) ->
        Enum.map(options, fn opt ->
          case opt do
            %{"label" => label} -> %{label: label || ""}
            %{label: label} -> %{label: label || ""}
            _ -> %{label: ""}
          end
        end)

      _ ->
        [%{label: ""}, %{label: ""}, %{label: ""}, %{label: ""}]
    end
  end

  defp parse_datetime_params(market_params) do
    # Parse voting_start and voting_end from datetime-local format
    market_params
    |> maybe_parse_datetime("voting_start")
    |> maybe_parse_datetime("voting_end")
  end

  defp maybe_parse_datetime(params, field) do
    case Map.get(params, field) do
      "" ->
        Map.put(params, field, nil)

      nil ->
        params

      datetime_str ->
        # DateTime-local inputs send format like "2024-01-01T10:00"
        case NaiveDateTime.from_iso8601(datetime_str) do
          {:ok, naive} ->
            datetime = DateTime.from_naive!(naive, "Etc/UTC")
            Map.put(params, field, datetime)

          _ ->
            # Try with seconds already included
            case NaiveDateTime.from_iso8601(datetime_str <> ":00") do
              {:ok, naive} ->
                datetime = DateTime.from_naive!(naive, "Etc/UTC")
                Map.put(params, field, datetime)

              _ ->
                params
            end
        end
    end
  end

  defp extract_options_error(changeset) do
    case changeset.errors[:options] do
      {message, _opts} -> message
      nil -> nil
    end
  end

  defp extract_voting_window_error(changeset) do
    case changeset.errors[:voting_end] do
      {message, _opts} -> message
      nil -> nil
    end
  end
end

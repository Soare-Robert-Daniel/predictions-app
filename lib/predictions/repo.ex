defmodule Predictions.Repo do
  use Ecto.Repo,
    otp_app: :predictions,
    adapter: Ecto.Adapters.SQLite3
end

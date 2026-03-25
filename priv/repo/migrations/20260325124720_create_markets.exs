defmodule Predictions.Repo.Migrations.CreateMarkets do
  use Ecto.Migration

  def change do
    create table(:markets) do
      add :question, :string, null: false
      add :voting_start, :utc_datetime, null: false
      add :voting_end, :utc_datetime, null: false
      add :outcome, :string
      add :resolved_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end
  end
end

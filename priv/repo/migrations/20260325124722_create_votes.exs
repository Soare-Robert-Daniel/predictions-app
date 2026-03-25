defmodule Predictions.Repo.Migrations.CreateVotes do
  use Ecto.Migration

  def change do
    create table(:votes) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :market_id, references(:markets, on_delete: :delete_all), null: false
      add :market_option_id, references(:market_options, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    # One vote per user per market - critical for vote integrity
    create unique_index(:votes, [:user_id, :market_id])
    create index(:votes, [:market_id])
    create index(:votes, [:market_option_id])
  end
end

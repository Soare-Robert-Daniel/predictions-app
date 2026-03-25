defmodule Predictions.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :market_id, references(:markets, on_delete: :delete_all), null: false
      add :message, :string, null: false
      add :read, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    # One notification per user per market for resolution notifications
    create unique_index(:notifications, [:user_id, :market_id])
    create index(:notifications, [:user_id])
  end
end

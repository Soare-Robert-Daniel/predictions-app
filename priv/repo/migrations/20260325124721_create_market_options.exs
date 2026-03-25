defmodule Predictions.Repo.Migrations.CreateMarketOptions do
  use Ecto.Migration

  def change do
    create table(:market_options) do
      add :label, :string, null: false
      add :position, :integer, null: false, default: 0
      add :market_id, references(:markets, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:market_options, [:market_id])
    create index(:market_options, [:market_id, :position])
  end
end

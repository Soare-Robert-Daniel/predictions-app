defmodule Predictions.Repo.Migrations.AddWinningOptionIdToMarkets do
  use Ecto.Migration

  def change do
    alter table(:markets) do
      add :winning_option_id, references(:market_options, on_delete: :nilify_all)
    end

    create index(:markets, [:winning_option_id])
  end
end

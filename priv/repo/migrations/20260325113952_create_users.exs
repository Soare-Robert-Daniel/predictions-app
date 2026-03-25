defmodule Predictions.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string, null: false
      add :hashed_password, :string, null: false
      add :role, :string, null: false, default: "user"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
  end
end

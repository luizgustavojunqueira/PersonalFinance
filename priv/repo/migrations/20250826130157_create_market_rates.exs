defmodule PersonalFinance.Repo.Migrations.CreateMarketRates do
  use Ecto.Migration

  def change do
    create table(:market_rates) do
      add :type, :string, null: false
      add :value, :decimal, null: false
      add :date, :date, null: false

      timestamps()
    end
  end
end

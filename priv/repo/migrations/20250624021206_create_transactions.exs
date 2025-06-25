defmodule PersonalFinance.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions) do
      add :value, :float
      add :amount, :float
      add :description, :string

      timestamps(type: :utc_datetime)
    end
  end
end

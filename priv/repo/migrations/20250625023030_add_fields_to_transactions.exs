defmodule PersonalFinance.Repo.Migrations.AddFieldsToTransactions do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add :date, :date
      add :category, :string
      add :type, :string
      add :total_value, :float
    end

    create index(:transactions, [:date])
    create index(:transactions, [:category])
    create index(:transactions, [:type])
  end
end

defmodule PersonalFinance.Repo.Migrations.EditFixedIncome do
  use Ecto.Migration

  def change do
    alter table(:fixed_income) do
      add :is_active, :boolean, default: true, null: false
      add :total_tax_deducted, :decimal, precision: 15, scale: 2, default: 0.0, null: false
      add :total_yield, :decimal, precision: 15, scale: 2, default: 0.0, null: false
    end

    alter table(:fixed_income_transactions) do
      add :tax, :decimal, precision: 10, scale: 6, null: true
    end
  end
end

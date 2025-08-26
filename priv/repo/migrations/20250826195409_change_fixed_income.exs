defmodule PersonalFinance.Repo.Migrations.ChangeFixedIncome do
  use Ecto.Migration

  def change do
    alter table(:fixed_income) do
      modify :start_date, :utc_datetime
      modify :end_date, :utc_datetime
      modify :last_yield_date, :utc_datetime
    end

    alter table(:fixed_income_transactions) do
      modify :date, :utc_datetime
    end
  end
end

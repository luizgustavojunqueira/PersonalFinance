defmodule PersonalFinance.Repo.Migrations.CreateGoals do
  use Ecto.Migration

  def change do
    create table(:goals) do
      add :name, :string, null: false
      add :description, :text
      add :target_amount, :decimal, null: false
      add :target_date, :date
      add :color, :string, size: 20
      add :profile_id, references(:profiles, on_delete: :nothing)
      add :ledger_id, references(:ledgers, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:goals, [:ledger_id])
    create index(:goals, [:profile_id])
    create unique_index(:goals, [:ledger_id, :name])

    create table(:goal_fixed_incomes) do
      add :goal_id, references(:goals, on_delete: :delete_all), null: false
      add :fixed_income_id, references(:fixed_income, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:goal_fixed_incomes, [:goal_id])
    create index(:goal_fixed_incomes, [:fixed_income_id])
    create unique_index(:goal_fixed_incomes, [:goal_id, :fixed_income_id])
  end
end

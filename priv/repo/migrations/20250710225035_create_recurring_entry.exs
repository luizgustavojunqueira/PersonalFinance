defmodule PersonalFinance.Repo.Migrations.CreateRecurringEntry do
  use Ecto.Migration

  def change do
    create table(:recurring_entries) do
      add :description, :string, null: false
      add :amount, :float, null: false
      add :value, :float, null: false
      add :start_date, :date, null: false
      add :end_date, :date
      add :day_of_month, :integer, null: true
      add :frequency, :string, null: false
      add :type, :string, null: false
      add :is_active, :boolean, default: true, null: false

      add :budget_id, references(:budgets, on_delete: :delete_all), null: false
      add :profile_id, references(:profiles, on_delete: :nothing), null: false
      add :category_id, references(:categories, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    alter table(:transactions) do
      add :recurring_entry_id, references(:recurring_entries, on_delete: :nothing), null: true
    end
  end
end

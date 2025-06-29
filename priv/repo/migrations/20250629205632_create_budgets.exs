defmodule PersonalFinance.Repo.Migrations.Createbudget do
  use Ecto.Migration

  def change do
    create table(:budgets) do
      add :name, :string
      add :description, :string, default: nil
      add :owner_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:budgets, [:name, :owner_id], name: :unique_budget_name_per_owner)

    drop index(:transactions, [:user_id])

    alter table(:transactions) do
      add :budget_id, references(:budgets, on_delete: :delete_all), null: true
      remove :user_id
    end

    drop_if_exists index(:categories, [:name, :user_id], name: :unique_default_category_per_user)

    drop_if_exists index(:categories, [:is_default, :user_id],
                     name: :unique_category_name_per_user
                   )

    alter table(:categories) do
      add :budget_id, references(:budgets, on_delete: :delete_all), null: true
      remove :user_id
    end

    create unique_index(:categories, [:name, :budget_id],
             name: :unique_category_name_per_budget
           )

    create unique_index(:categories, [:is_default, :budget_id],
             name: :unique_default_category_per_budget,
             where: "is_default = true"
           )

    alter table(:profiles) do
      add :budget_id, references(:budgets, on_delete: :delete_all), null: true
      remove :user_id
    end

    create table(:budgets_users) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :budget_id, references(:budgets, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:budgets_users, [:budget_id, :user_id], name: :unique_budget_user)

    create index(:transactions, [:budget_id])
    create index(:categories, [:budget_id])
    create index(:profiles, [:budget_id])
  end
end

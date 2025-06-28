defmodule PersonalFinance.Repo.Migrations.AddUserId do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
    end

    create index(:transactions, [:user_id])

    alter table(:categories) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
    end
  end
end

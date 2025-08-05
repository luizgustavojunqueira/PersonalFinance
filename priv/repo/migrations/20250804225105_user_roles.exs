defmodule PersonalFinance.Repo.Migrations.UserRoles do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :role, :string, default: "user", null: false
    end

    create index(:users, [:role])
  end
end

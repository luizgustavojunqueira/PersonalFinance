defmodule PersonalFinance.Repo.Migrations.AddProfileDefault do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      add :is_default, :boolean, default: false, null: false
    end

    create unique_index(:profiles, [:budget_id, :is_default],
             where: "is_default = true",
             name: :unique_default_profile_per_budget
           )

    create unique_index(:profiles, [:name, :budget_id], name: :unique_profile_name_per_budget)
  end
end

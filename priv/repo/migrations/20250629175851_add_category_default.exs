defmodule PersonalFinance.Repo.Migrations.AddCategoryDefault do
  use Ecto.Migration

  def change do
    alter table(:categories) do
      add :is_default, :boolean, default: false, null: false
      add :is_fixed, :boolean, default: false, null: false
    end

    create unique_index(:categories, [:is_default, :user_id],
             name: :unique_default_category_per_user,
             where: "is_default = true"
           )

    create unique_index(:categories, [:name, :user_id], name: :unique_category_name_per_user)
  end
end

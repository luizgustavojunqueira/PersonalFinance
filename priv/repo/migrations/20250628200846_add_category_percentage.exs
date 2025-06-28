defmodule PersonalFinance.Repo.Migrations.AddCategoryPercentage do
  use Ecto.Migration

  def change do
    alter table(:categories) do
      add :percentage, :float, default: 0.0, null: false
    end
  end
end

defmodule PersonalFinance.Repo.Migrations.AddColors do
  use Ecto.Migration

  def change do
    alter table(:categories) do
      add :color, :string, null: false, default: "#000000"
    end

    alter table(:profiles) do
      add :color, :string, null: false, default: "#000000"
    end
  end
end

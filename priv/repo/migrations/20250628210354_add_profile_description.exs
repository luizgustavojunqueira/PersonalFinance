defmodule PersonalFinance.Repo.Migrations.AddProfileDescription do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      add :description, :text, null: true
    end
  end
end

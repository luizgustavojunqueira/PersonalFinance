defmodule PersonalFinance.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:categories) do
      add :name, :string
      add :description, :string

      timestamps(type: :utc_datetime)
    end

    create table(:investment_types) do
      add :name, :string
      add :description, :string

      timestamps(type: :utc_datetime)
    end

    create table(:profiles) do
      add :name, :string
      add :user_id, references(:users, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create table(:transactions) do
      add :value, :float
      add :amount, :float
      add :total_value, :float
      add :description, :string
      add :category_id, references(:categories, on_delete: :nothing)
      add :investment_type_id, references(:investment_types, on_delete: :nothing)
      add :profile_id, references(:profiles, on_delete: :nothing)
      add :date, :date

      timestamps(type: :utc_datetime)
    end
  end
end

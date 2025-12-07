defmodule PersonalFinance.Repo.Migrations.CreateCategorySuggestions do
  use Ecto.Migration

  def change do
    create table(:category_suggestions) do
      add :normalized_description, :string, null: false
      add :count, :integer, null: false, default: 1

      add :ledger_id, references(:ledgers, on_delete: :delete_all), null: false
      add :category_id, references(:categories, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:category_suggestions, [:ledger_id])
    create index(:category_suggestions, [:category_id])

    create unique_index(:category_suggestions, [:ledger_id, :normalized_description, :category_id],
             name: :category_suggestions_ledger_description_category_index
           )

    create index(:category_suggestions, [:ledger_id, :normalized_description])
  end
end

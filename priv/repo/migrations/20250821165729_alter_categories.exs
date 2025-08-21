defmodule PersonalFinance.Repo.Migrations.AlterCategories do
  use Ecto.Migration

  def up do
    alter table(:categories) do
      add :is_investment, :boolean, default: false, null: false
    end

    execute """
    UPDATE categories 
    SET is_investment = true 
    WHERE name = 'Investimento'
    """

    create unique_index(:categories, [:ledger_id],
             where: "is_investment = true",
             name: :categories_unique_investment_per_ledger
           )
  end

  def down do
    drop_if_exists index(:categories, [:ledger_id],
                     name: :categories_unique_investment_per_ledger
                   )

    alter table(:categories) do
      remove :is_investment
    end
  end
end

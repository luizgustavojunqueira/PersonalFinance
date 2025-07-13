defmodule PersonalFinance.Repo.Migrations.AddTransactionType do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add :type, :string, null: false, default: "expense"
    end
  end
end

defmodule PersonalFinance.Repo.Migrations.AddDraftToTransactions do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add :draft, :boolean, default: false, null: false
    end
  end
end

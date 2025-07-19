defmodule PersonalFinance.Repo.Migrations.RemoveBalance do
  use Ecto.Migration

  def change do
    alter table(:ledgers) do
      remove :balance
    end
  end
end

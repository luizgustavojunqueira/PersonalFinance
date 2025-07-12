defmodule PersonalFinance.Repo.Migrations.RemoveDayOfMonth do
  use Ecto.Migration

  def change do
    alter table(:recurring_entries) do
      remove :day_of_month
    end
  end
end

defmodule PersonalFinance.Repo.Migrations.AddTimes do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      modify :date, :utc_datetime
    end

    alter table(:recurring_entries) do
      modify :start_date, :utc_datetime
      modify :end_date, :utc_datetime
    end
  end

  def down do
    alter table(:transactions) do
      modify :date, :date
    end

    alter table(:recurring_entries) do
      modify :start_date, :date
      modify :end_date, :date
    end
  end
end

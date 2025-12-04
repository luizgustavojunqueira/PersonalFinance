defmodule PersonalFinance.Repo.Migrations.AddNotesToLedgersAndProfiles do
  use Ecto.Migration

  def change do
    alter table(:ledgers) do
      add :notes, :text
    end

    alter table(:profiles) do
      add :notes, :text
    end
  end
end

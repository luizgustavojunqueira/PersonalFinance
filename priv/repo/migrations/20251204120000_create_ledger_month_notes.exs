defmodule PersonalFinance.Repo.Migrations.CreateLedgerMonthNotes do
  use Ecto.Migration

  def change do
    create table(:ledger_month_notes) do
      add :ledger_id, references(:ledgers, on_delete: :delete_all), null: false
      add :year, :integer, null: false
      add :month, :integer, null: false
      add :content, :text

      timestamps(type: :utc_datetime)
    end

    create index(:ledger_month_notes, [:ledger_id])

    create unique_index(:ledger_month_notes, [:ledger_id, :year, :month],
             name: :ledger_month_notes_ledger_year_month_index
           )
  end
end

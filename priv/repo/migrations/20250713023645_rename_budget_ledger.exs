defmodule PersonalFinance.Repo.Migrations.RenameBudgetLedger do
  use Ecto.Migration

  def change do
    rename table(:budgets), to: table(:ledgers)

    rename table(:transactions), :budget_id, to: :ledger_id

    alter table(:transactions) do
      modify :ledger_id, references(:ledgers, on_delete: :delete_all), null: false
    end

    rename table(:profiles), :budget_id, to: :ledger_id

    alter table(:profiles) do
      modify :ledger_id, references(:ledgers, on_delete: :delete_all), null: false
    end

    rename table(:categories), :budget_id, to: :ledger_id

    alter table(:categories) do
      modify :ledger_id, references(:ledgers, on_delete: :delete_all), null: false
    end

    rename table(:recurring_entries), :budget_id, to: :ledger_id

    alter table(:recurring_entries) do
      modify :ledger_id, references(:ledgers, on_delete: :delete_all), null: false
    end

    rename table(:budgets_users), :budget_id, to: :ledger_id
    rename table(:budgets_users), to: table(:ledgers_users)

    alter table(:ledgers_users) do
      modify :ledger_id, references(:ledgers, on_delete: :delete_all), null: false
    end

    rename table(:budget_invites), :budget_id, to: :ledger_id
    rename table(:budget_invites), to: table(:ledger_invites)

    alter table(:ledger_invites) do
      modify :ledger_id, references(:ledgers, on_delete: :delete_all), null: false
    end

    alter table(:ledgers) do
      add :balance, :float, default: 0.0, null: false
    end
  end
end

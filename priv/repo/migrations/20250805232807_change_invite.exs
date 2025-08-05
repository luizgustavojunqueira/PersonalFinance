defmodule PersonalFinance.Repo.Migrations.ChangeInvite do
  use Ecto.Migration

  def change do
    drop table(:ledger_invites)
  end
end

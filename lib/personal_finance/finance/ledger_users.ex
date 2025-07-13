defmodule PersonalFinance.Finance.LedgersUsers do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ledgers_users" do
    belongs_to :ledger, PersonalFinance.Finance.Ledger
    belongs_to :user, PersonalFinance.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc false
  def changeset(ledger_user, attrs) do
    ledger_user
    |> cast(attrs, [:ledger_id, :user_id])
    |> validate_required([:ledger_id, :user_id])
    |> unique_constraint(:ledger_id, name: :budget_users_budget_id_user_id_index)
  end
end

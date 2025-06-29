defmodule PersonalFinance.Finance.BudgetUser do
  use Ecto.Schema
  import Ecto.Changeset

  schema "budget_users" do
    belongs_to :budget, PersonalFinance.Finance.Budget
    belongs_to :user, PersonalFinance.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(budget_user, attrs) do
    budget_user
    |> cast(attrs, [:budget_id, :user_id])
    |> validate_required([:budget_id, :user_id])
    |> unique_constraint(:budget_id, name: :budget_users_budget_id_user_id_index)
  end
end

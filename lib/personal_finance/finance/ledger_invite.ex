defmodule PersonalFinance.Finance.LedgerInvite do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ledger_invites" do
    field :email, :string
    field :token, :string
    field :status, Ecto.Enum, values: [:pending, :accepted, :declined], default: :pending
    field :expires_at, :naive_datetime

    belongs_to :ledger, PersonalFinance.Finance.Ledger
    belongs_to :inviter, PersonalFinance.Accounts.User
    belongs_to :invited_user, PersonalFinance.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(ledger_invite, attrs) do
    ledger_invite
    |> cast(attrs, [
      :email,
      :token,
      :ledger_id,
      :inviter_id,
      :invited_user_id,
      :status,
      :expires_at
    ])
    |> validate_required([:email, :token, :ledger_id, :inviter_id, :status, :expires_at])
    |> unique_constraint(:token, name: :ledger_invites_token_index)
    |> unique_constraint(:email, name: :ledger_invites_email_budget_id_index)
    |> unique_constraint(:token, name: :ledger_invites_token_budget_id_index)
  end
end

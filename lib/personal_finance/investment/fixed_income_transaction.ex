defmodule PersonalFinance.Investment.FixedIncomeTransaction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "fixed_income_transactions" do
    field :type, Ecto.Enum, values: [:deposit, :withdraw, :yield, :tax, :fee]
    field :value, :decimal
    field :date, :utc_datetime
    field :description, :string
    field :yield_rate, :decimal
    field :is_automatic, :boolean, default: false
    field :reference_period, :string
    field :tax, :decimal

    belongs_to :profile, PersonalFinance.Accounts.Profile
    belongs_to :fixed_income, PersonalFinance.Investment.FixedIncome
    belongs_to :ledger, PersonalFinance.Finance.Ledger
    belongs_to :transaction, PersonalFinance.Finance.Transaction

    timestamps(type: :utc_datetime)
  end

  def changeset(fixed_income_transaction, attrs, ledger_id) do
    fixed_income_transaction
    |> cast(attrs, [
      :type,
      :value,
      :date,
      :description,
      :yield_rate,
      :reference_period,
      :fixed_income_id,
      :profile_id,
      :transaction_id
    ])
    |> validate_required(
      [:type, :value, :date, :fixed_income_id, :profile_id],
      message: "Este campo é obrigatório"
    )
    |> validate_inclusion(:type, [:deposit, :withdraw, :yield, :tax, :fee],
      message: "Tipo de transação inválido"
    )
    |> validate_number(:value, greater_than: 0, message: "O valor deve ser maior que zero")
    |> validate_length(:description,
      max: 255,
      message: "A descrição deve ter no máximo 255 caracteres"
    )
    |> put_change(:ledger_id, ledger_id)
    |> put_change(:is_automatic, false)
  end

  def system_changeset(fixed_income_transaction, attrs) do
    fixed_income_transaction
    |> cast(attrs, [
      :type,
      :value,
      :date,
      :description,
      :yield_rate,
      :reference_period,
      :fixed_income_id,
      :profile_id,
      :transaction_id,
      :ledger_id,
      :tax
    ])
    |> validate_required(
      [:type, :value, :date, :fixed_income_id, :profile_id, :ledger_id],
      message: "Este campo é obrigatório"
    )
    |> put_change(:is_automatic, true)
  end
end

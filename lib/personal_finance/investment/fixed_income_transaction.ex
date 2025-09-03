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
    |> put_change(:ledger_id, ledger_id)
    |> put_change(:is_automatic, false)
    |> validate_required(
      [:type, :value, :date, :fixed_income_id, :profile_id],
      message: "Este campo é obrigatório"
    )
    |> validate_inclusion(:type, [:deposit, :withdraw, :yield, :tax, :fee],
      message: "Tipo de transação inválido"
    )
    |> validate_number(:value, greater_than: 0, message: "O valor deve ser maior que zero")
    |> validate_max_withdraw()
    |> validate_length(:description,
      max: 255,
      message: "A descrição deve ter no máximo 255 caracteres"
    )
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
    |> validate_max_withdraw()
    |> put_change(:is_automatic, true)
  end

  defp validate_max_withdraw(changeset) do
    changeset
    |> validate_change(:type, fn :type, type ->
      if type == :withdraw do
        fixed_income_id = get_field(changeset, :fixed_income_id)
        value = get_field(changeset, :value)
        ledger_id = get_field(changeset, :ledger_id)

        if fixed_income_id && value do
          current_balance =
            PersonalFinance.Investment.get_fixed_income(fixed_income_id, ledger_id).current_balance

          if Decimal.cmp(value, Decimal.from_float(current_balance)) == :gt do
            [value: "O valor do resgate não pode ser maior que o saldo atual"]
          else
            []
          end
        else
          []
        end
      else
        []
      end
    end)
  end
end

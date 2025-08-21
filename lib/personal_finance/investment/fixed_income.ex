defmodule PersonalFinance.Investment.FixedIncome do
  use Ecto.Schema
  import Ecto.Changeset

  schema "fixed_income" do
    field :name, :string
    field :institution, :string
    field :type, Ecto.Enum, values: [:cdb]
    field :start_date, :date
    field :end_date, :date
    field :remuneration_rate, :decimal

    field :remuneration_basis, Ecto.Enum,
      values: [:cdi, :ipca, :selic, :fixed_yearly, :fixed_monthly]

    field :yield_frequency, Ecto.Enum,
      values: [:monthly, :quarterly, :semi_annually, :annually, :at_maturity]

    field :is_tax_exempt, :boolean, default: false
    field :initial_investment, :float
    field :current_balance, :float
    field :last_yield_date, :date

    belongs_to :profile, PersonalFinance.Accounts.Profile
    belongs_to :ledger, PersonalFinance.Finance.Ledger
    has_many :fixed_income_transactions, PersonalFinance.Investment.FixedIncomeTransaction

    timestamps(type: :utc_datetime)
  end

  def changeset(fixed_income, attrs, ledger_id) do
    fixed_income
    |> cast(attrs, [
      :name,
      :institution,
      :type,
      :start_date,
      :end_date,
      :remuneration_rate,
      :remuneration_basis,
      :yield_frequency,
      :is_tax_exempt,
      :initial_investment,
      :current_balance,
      :last_yield_date,
      :profile_id
    ])
    |> validate_required(
      [
        :name,
        :institution,
        :type,
        :start_date,
        :remuneration_rate,
        :remuneration_basis,
        :yield_frequency,
        :initial_investment,
        :profile_id
      ],
      message: "Este campo é obrigatório"
    )
    |> common_validations()
    |> put_change(:ledger_id, ledger_id)
    |> unique_constraint(:name,
      name: :fixed_income_name_profile_id_index,
      message: "Você já possui um investimento com este nome"
    )
    |> set_initial_balance()
  end

  def system_changeset(fixed_income, attrs) do
    fixed_income
    |> cast(attrs, [:current_balance, :last_yield_date])
    |> validate_number(:current_balance,
      greater_than_or_equal_to: 0
    )
  end

  def update_changeset(fixed_income, attrs) do
    fixed_income
    |> cast(attrs, [:name, :institution, :end_date])
    |> common_validations()
  end

  defp common_validations(changeset) do
    changeset
    |> validate_length(:name, max: 100, message: "O nome deve ter no máximo 100 caracteres")
    |> validate_length(:institution,
      max: 100,
      message: "A instituição deve ter no máximo 100 caracteres"
    )
  end

  defp set_initial_balance(changeset) do
    case get_change(changeset, :initial_investment) do
      nil -> changeset
      initial_investment -> put_change(changeset, :current_balance, initial_investment)
    end
  end
end

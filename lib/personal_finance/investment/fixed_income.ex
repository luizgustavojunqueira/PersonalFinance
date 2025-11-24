defmodule PersonalFinance.Investment.FixedIncome do
  use Ecto.Schema
  import Ecto.Changeset
  use Gettext, backend: PersonalFinanceWeb.Gettext

  schema "fixed_income" do
    field :name, :string
    field :institution, :string
    field :type, Ecto.Enum, values: [:cdb]
    field :start_date, :utc_datetime
    field :start_date_input, :date, virtual: true
    field :end_date, :utc_datetime
    field :remuneration_rate, :decimal
    field :is_active, :boolean, default: true
    field :total_tax_deducted, :decimal, default: Decimal.new("0.0")
    field :total_yield, :decimal, default: Decimal.new("0.0")

    field :remuneration_basis, Ecto.Enum,
      values: [:cdi, :ipca, :selic, :fixed_yearly, :fixed_monthly]

    field :yield_frequency, Ecto.Enum,
      values: [:daily, :monthly, :quarterly, :semi_annually, :annually, :at_maturity]

    field :is_tax_exempt, :boolean, default: false
    field :initial_investment, :float
    field :current_balance, :float
    field :last_yield_date, :utc_datetime

    belongs_to :profile, PersonalFinance.Finance.Profile
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
      :start_date_input,
      :end_date,
      :remuneration_rate,
      :remuneration_basis,
      :yield_frequency,
      :is_tax_exempt,
      :initial_investment,
      :current_balance,
      :last_yield_date,
      :profile_id,
      :is_active
    ])
    |> convert_date_to_datetime()
    |> common_validations()
    |> put_change(:ledger_id, ledger_id)
    |> unique_constraint(:name,
      name: :fixed_income_name_profile_id_index,
      message: gettext("You already have an investment with this name.")
    )
    |> set_initial_balance()
  end

  def system_changeset(fixed_income, attrs) do
    fixed_income
    |> cast(attrs, [
      :current_balance,
      :initial_investment,
      :last_yield_date,
      :is_active,
      :total_tax_deducted,
      :total_yield,
      :start_date
    ])
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
    |> validate_required(:name, message: gettext("Name is required."))
    |> validate_required(:institution, message: gettext("Institution is required."))
    |> validate_required(:type, message: gettext("Investment type is required."))
    |> validate_required(:remuneration_rate, message: gettext("Remuneration rate is required."))
    |> validate_required(:remuneration_basis, message: gettext("Remuneration basis is required."))
    |> validate_required(:yield_frequency, message: gettext("Yield frequency is required."))
    |> validate_required(:initial_investment, message: gettext("Initial investment is required."))
    |> validate_required(:start_date_input, message: gettext("Start date is required."))
    |> validate_required(:start_date, message: gettext("Start date is required."))
    |> validate_required(:profile_id, message: gettext("Profile is required."))
    |> validate_inclusion(:is_tax_exempt, [true, false],
      message: gettext("Please indicate whether the investment is tax exempt.")
    )
    |> validate_inclusion(:type, [:cdb], message: gettext("Invalid investment type."))
    |> validate_number(:remuneration_rate,
      greater_than: 0,
      message: gettext("Remuneration rate must be greater than zero.")
    )
    |> validate_number(:initial_investment,
      greater_than: 0,
      message: gettext("Initial investment must be greater than zero.")
    )
    |> validate_number(:current_balance,
      greater_than_or_equal_to: 0,
      message: gettext("Current balance cannot be negative.")
    )
    |> validate_inclusion(
      :remuneration_basis,
      [:cdi, :ipca, :selic, :fixed_yearly, :fixed_monthly],
      message: gettext("Invalid remuneration basis.")
    )
    |> validate_inclusion(
      :yield_frequency,
      [:daily, :monthly, :quarterly, :semi_annually, :annually, :at_maturity],
      message: gettext("Invalid yield frequency.")
    )
    |> validate_change(:end_date, fn :end_date, end_date ->
      case get_field(changeset, :start_date) do
        nil ->
          []

        _start_date when is_nil(end_date) ->
          []

        start_date ->
          if DateTime.compare(end_date, start_date) == :lt do
            [end_date: gettext("End date must be after the start date.")]
          else
            []
          end
      end
    end)
    |> validate_length(:name, max: 100, message: gettext("Name must be at most 100 characters."))
    |> validate_length(:institution,
      max: 100,
      message: gettext("Institution must be at most 100 characters.")
    )
  end

  defp set_initial_balance(changeset) do
    case get_change(changeset, :initial_investment) do
      nil -> changeset
      initial_investment -> put_change(changeset, :current_balance, initial_investment)
    end
  end

  defp convert_date_to_datetime(%Ecto.Changeset{valid?: true} = changeset) do
    case get_change(changeset, :start_date_input) do
      %Date{} = date ->
        datetime =
          DateTime.new!(date, Time.utc_now(), "Etc/UTC")
          |> DateTime.truncate(:second)

        changeset
        |> put_change(:start_date, datetime)
        |> validate_required([:start_date])

      nil ->
        changeset

      _ ->
        changeset
    end
  end

  defp convert_date_to_datetime(changeset), do: changeset
end

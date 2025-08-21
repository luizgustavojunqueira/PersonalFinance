defmodule PersonalFinance.Investment do
  @moduledoc """
  Context for managing investment operations, particularly fixed income investments.
  """

  alias PersonalFinance.Finance
  alias PersonalFinance.Repo
  alias PersonalFinance.Accounts.Scope
  alias PersonalFinance.Finance.{Ledger}
  alias PersonalFinance.Investment.{FixedIncome, FixedIncomeTransaction}

  import Ecto.Query

  @doc """
  Create a fixed income changeset with the given attributes and ledger ID.
  """
  def change_fixed_income(
        %FixedIncome{} = fixed_income,
        %Ledger{} = ledger,
        attrs,
        profile_id
      ) do
    attrs_with_profile = Map.put(attrs, :profile_id, profile_id)

    fixed_income
    |> FixedIncome.changeset(attrs_with_profile, ledger.id)
  end

  @doc """
  Create a fixed income transaction changeset with the given attributes, fixed income, ledger ID, and profile ID.
  """
  def change_fixed_income_transaction(
        %FixedIncomeTransaction{} = fi_transaction,
        %FixedIncome{} = fixed_income,
        %Ledger{} = ledger,
        attrs,
        profile_id
      ) do
    attrs_with_relations =
      attrs
      |> Map.put(:fixed_income_id, fixed_income.id)
      |> Map.put(:profile_id, profile_id)

    fi_transaction
    |> FixedIncomeTransaction.changeset(attrs_with_relations, ledger.id)
  end

  @doc """
  Creates a new fixed income investment with its initial deposit transaction.

  This function performs the following operations in a transaction:
  1. Creates the fixed income record
  2. Creates an initial deposit transaction for the fixed income
  3. Creates a general ledger transaction for the investment
  """
  def create_fixed_income(attrs, %Ledger{} = ledger, profile_id) do
    Repo.transaction(fn ->
      with {:ok, fixed_income} <- create_fixed_income_record(attrs, ledger, profile_id),
           {:ok, _initial_transaction} <-
             create_initial_deposit_transaction(fixed_income, ledger),
           {:ok, _general_transaction} <-
             create_general_investment_transaction(fixed_income, ledger) do
        fixed_income
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Gets a fixed income by ID, scoped to the user's profile.
  """
  def get_fixed_income(id, profile_id) do
    from(fi in FixedIncome,
      where: fi.id == ^id and fi.profile_id == ^profile_id,
      preload: [:profile, :ledger]
    )
    |> Repo.one()
  end

  @doc """
  Lists all fixed income investments for a profile.
  """
  def list_fixed_incomes(profile_id) do
    from(fi in FixedIncome,
      where: fi.profile_id == ^profile_id,
      order_by: [desc: fi.inserted_at],
      preload: [:ledger]
    )
    |> Repo.all()
  end

  @doc """
  Updates a fixed income investment (limited fields for user updates).
  """
  def update_fixed_income(%FixedIncome{} = fixed_income, attrs) do
    fixed_income
    |> FixedIncome.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Calculates the current balance of a fixed income based on its transactions.
  """
  def calculate_balance(%FixedIncome{id: id}) do
    query =
      from t in FixedIncomeTransaction,
        where: t.fixed_income_id == ^id,
        select: %{
          deposits:
            sum(fragment("CASE WHEN ? IN ('deposit') THEN ? ELSE 0 END", t.type, t.value)),
          withdrawals:
            sum(fragment("CASE WHEN ? IN ('withdraw') THEN ? ELSE 0 END", t.type, t.value)),
          yields: sum(fragment("CASE WHEN ? IN ('yield') THEN ? ELSE 0 END", t.type, t.value)),
          fees_and_taxes:
            sum(fragment("CASE WHEN ? IN ('tax', 'fee') THEN ? ELSE 0 END", t.type, t.value))
        }

    result = Repo.one(query)

    deposits = Decimal.new(result.deposits || 0)
    withdrawals = Decimal.new(result.withdrawals || 0)
    yields = Decimal.new(result.yields || 0)
    fees_and_taxes = Decimal.new(result.fees_and_taxes || 0)

    deposits
    |> Decimal.add(yields)
    |> Decimal.sub(withdrawals)
    |> Decimal.sub(fees_and_taxes)
    |> Decimal.to_float()
  end

  @doc """
  Updates the cached balance of a fixed income investment.
  """
  def update_balance(%FixedIncome{} = fixed_income, %FixedIncomeTransaction{} = fi_transaction) do
    new_balance = calculate_balance(fixed_income)

    fixed_income
    |> FixedIncome.system_changeset(%{
      current_balance: new_balance,
      last_yield_date:
        if(fi_transaction.type == :yield,
          do: fi_transaction.date,
          else: fixed_income.last_yield_date
        )
    })
    |> Repo.update()
  end

  @doc """
  Creates a new transaction for a fixed income investment.
  """
  def create_transaction(
        %FixedIncome{} = fixed_income,
        attrs,
        %Ledger{} = ledger,
        profile_id
      ) do
    Repo.transaction(fn ->
      with {:ok, fi_transaction} <-
             create_fixed_income_transaction(attrs, fixed_income, ledger, profile_id),
           {:ok, _general_transaction} <-
             create_corresponding_general_transaction(fi_transaction, ledger),
           {:ok, _updated_fi} <- update_balance(fixed_income, fi_transaction) do
        fi_transaction
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Gets transactions for a fixed income investment.
  """
  def list_transactions(%FixedIncome{id: fixed_income_id}, profile_id) do
    from(t in FixedIncomeTransaction,
      where: t.fixed_income_id == ^fixed_income_id and t.profile_id == ^profile_id,
      order_by: [desc: t.date, desc: t.inserted_at],
      preload: [:transaction]
    )
    |> Repo.all()
  end

  defp create_fixed_income_record(attrs, ledger, profile_id) do
    change_fixed_income(%FixedIncome{}, ledger, attrs, profile_id)
    |> Repo.insert()
  end

  defp create_initial_deposit_transaction(fixed_income, ledger) do
    attrs = %{
      type: :deposit,
      value: fixed_income.initial_investment,
      date: fixed_income.start_date,
      description: "Investimento inicial",
      is_automatic: true
    }

    create_fixed_income_transaction(attrs, fixed_income, ledger, fixed_income.profile_id)
  end

  defp create_general_investment_transaction(fixed_income, ledger) do
    investment_category = Finance.get_investment_category(%Scope{}, ledger.id)

    attrs = %{
      "description" => "Investimento em #{fixed_income.name}",
      "value" => fixed_income.initial_investment,
      "total_value" => fixed_income.initial_investment,
      "amount" => 1,
      "type" => :expense,
      "category_id" => investment_category.id,
      "date" => fixed_income.start_date,
      "ledger_id" => ledger.id,
      "profile_id" => fixed_income.profile_id
    }

    Finance.create_transaction(%Scope{}, attrs, ledger)
  end

  defp create_fixed_income_transaction(attrs, fixed_income, ledger, profile_id) do
    change_fixed_income_transaction(
      %FixedIncomeTransaction{},
      fixed_income,
      ledger,
      attrs,
      profile_id
    )
    |> Repo.insert()
  end

  defp create_corresponding_general_transaction(fi_transaction, ledger) do
    if fi_transaction.type in [:yield, :tax, :fee] do
      {:ok, nil}
    else
      description =
        case fi_transaction.type do
          :deposit -> "Depósito em #{get_fixed_income_name(fi_transaction.fixed_income_id)}"
          :withdraw -> "Retirada de #{get_fixed_income_name(fi_transaction.fixed_income_id)}"
        end

      general_type =
        case fi_transaction.type do
          :deposit -> :expense
          :withdraw -> :income
        end

      investment_category = Finance.get_investment_category(%Scope{}, ledger.id)

      attrs = %{
        "description" => description,
        "amount" => 1,
        "value" => Decimal.to_float(fi_transaction.value),
        "total_value" => Decimal.to_float(fi_transaction.value),
        "type" => general_type,
        "category_id" => investment_category.id,
        "date" => fi_transaction.date,
        "ledger_id" => ledger.id,
        "profile_id" => fi_transaction.profile_id
      }

      Finance.create_transaction(%Scope{}, attrs, ledger)
      |> case do
        {:ok, transaction} ->
          # Link the transactions
          fi_transaction
          |> FixedIncomeTransaction.changeset(%{transaction_id: transaction.id}, ledger.id)
          |> Repo.update()

          {:ok, transaction}

        error ->
          error
      end
    end
  end

  defp get_fixed_income_name(fixed_income_id) do
    case Repo.get(FixedIncome, fixed_income_id) do
      nil -> "Investimento"
      fi -> fi.name
    end
  end

  def generate_yield(%FixedIncome{} = fixed_income, %Ledger{} = ledger) do
    IO.inspect(fixed_income.yield_frequency)

    fixed_income.yield_frequency
    |> case do
      :daily ->
        with yield <- generate_daily_yield(fixed_income) do
          attrs = %{
            type: :yield,
            value: Decimal.from_float(yield),
            date: Date.utc_today(),
            description: "Rendimento diário",
            is_automatic: true
          }

          create_transaction(fixed_income, attrs, ledger, fixed_income.profile_id)
        end

      :monthly ->
        diff = business_days_between(fixed_income.last_yield_date, Date.utc_today())

        yield =
          generate_daily_yield(fixed_income, diff)

        attrs = %{
          type: :yield,
          value: Decimal.from_float(yield),
          date: Date.utc_today(),
          description: "Rendimento mensal",
          is_automatic: true
        }

        create_transaction(fixed_income, attrs, ledger, fixed_income.profile_id)

      _ ->
        {:error, "Unsupported yield frequency"}
    end
  end

  def generate_daily_yield(%FixedIncome{} = fixed_income, days_invested \\ 1) do
    cdi_annual = 0.13

    cdi_daily_rate = :math.pow(1 + cdi_annual, 1 / 252) - 1

    investment_percentage = Decimal.to_float(fixed_income.remuneration_rate) / 100

    investment_daily_rate = cdi_daily_rate * investment_percentage

    accumulated_factor = :math.pow(1 + investment_daily_rate, days_invested) - 1

    current_balance = fixed_income.current_balance
    current_balance * accumulated_factor
  end

  def business_days_between(from, to) do
    Date.range(from, to)
    |> Enum.count(&business_day?/1)
  end

  defp business_day?(%Date{} = date) do
    case Date.day_of_week(date) do
      # sábado
      6 -> false
      # domingo
      7 -> false
      _ -> true
    end
  end
end

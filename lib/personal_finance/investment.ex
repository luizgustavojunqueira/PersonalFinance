defmodule PersonalFinance.Investment do
  @moduledoc """
  Context for managing investment operations, particularly fixed income investments.
  """

  alias PersonalFinance.Repo
  alias PersonalFinance.Accounts.Scope
  alias PersonalFinance.Finance.{Ledger}
  alias PersonalFinance.Finance
  alias PersonalFinance.Investment.{FixedIncome, FixedIncomeTransaction}

  import Ecto.Query

  @doc """
  List fixed incomes for a given ledger.
  """
  def list_fixed_incomes(%Ledger{} = ledger) do
    from(fi in FixedIncome,
      where: fi.ledger_id == ^ledger.id,
      order_by: [desc: fi.inserted_at],
      preload: [:profile]
    )
    |> Repo.all()
  end

  @doc """
  Create a fixed income changeset with the given attributes and ledger ID.
  """
  def change_fixed_income(
        %FixedIncome{} = fixed_income,
        %Ledger{} = ledger,
        attrs,
        profile_id
      ) do
    attrs_with_profile = Map.put(attrs, "profile_id", profile_id)

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
      |> Map.put("fixed_income_id", fixed_income.id)
      |> Map.put("profile_id", profile_id)

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
        fixed_income = Repo.preload(fixed_income, :profile)
        Finance.broadcast(:fixed_income, ledger.id, {:saved, fixed_income})
        fixed_income
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Gets a fixed income by ID.
  """
  def get_fixed_income(id, ledger_id) do
    from(fi in FixedIncome,
      where: fi.id == ^id and fi.ledger_id == ^ledger_id,
      preload: [:profile]
    )
    |> Repo.one()
  end

  @doc """
  Updates a fixed income investment.
  """
  def update_fixed_income(%FixedIncome{} = fixed_income, attrs) do
    with {:ok, updated_fi} <-
           fixed_income
           |> FixedIncome.update_changeset(attrs)
           |> Repo.update() do
      updated_fi = Repo.preload(updated_fi, :profile)
      Finance.broadcast(:fixed_income, updated_fi.ledger_id, {:saved, updated_fi})
      {:ok, updated_fi}
    else
      {:error, changeset} -> {:error, changeset}
    end
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

    with {:ok, _updated_fi} <-
           fixed_income
           |> FixedIncome.system_changeset(%{
             current_balance: new_balance,
             last_yield_date:
               if(fi_transaction.type == :yield,
                 do: fi_transaction.date,
                 else: fixed_income.last_yield_date
               )
           })
           |> Repo.update() do
      fixed_income = Repo.preload(fixed_income, :profile)
      Finance.broadcast(:fixed_income, fixed_income.ledger_id, {:saved, fixed_income})
      {:ok, fixed_income}
    else
      {:error, changeset} -> {:error, changeset}
    end
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
  def list_transactions(%FixedIncome{id: fixed_income_id}, page \\ 1, page_size \\ 10) do
    query =
      from(t in FixedIncomeTransaction,
        where: t.fixed_income_id == ^fixed_income_id,
        order_by: [desc: t.date, desc: t.inserted_at],
        preload: [:transaction]
      )

    total_entries = Repo.aggregate(query, :count, :id)

    query =
      if page_size != :all do
        offset = (page - 1) * page_size
        from(t in query, limit: ^page_size, offset: ^offset)
      else
        query
      end

    entries = Repo.all(query)

    total_pages =
      if page_size != :all && total_entries > 0,
        do: div(total_entries + page_size - 1, page_size),
        else: 1

    %{
      entries: entries,
      page_number: page,
      page_size: page_size,
      total_entries: total_entries,
      total_pages: total_pages
    }
  end

  defp create_fixed_income_record(attrs, ledger, profile_id) do
    with {:ok, fixed_income = %FixedIncome{}} <-
           change_fixed_income(%FixedIncome{}, ledger, attrs, profile_id)
           |> Repo.insert() do
      preloaded_fixed_income = Repo.preload(fixed_income, :profile)
      Finance.broadcast(:fixed_income, ledger.id, {:saved, preloaded_fixed_income})

      {:ok, fixed_income}
    else
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp create_initial_deposit_transaction(fixed_income, ledger) do
    attrs = %{
      "type" => :deposit,
      "value" => fixed_income.initial_investment,
      "date" => fixed_income.start_date,
      "description" => "Investimento inicial",
      "is_automatic" => false
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
    attrs =
      attrs
      |> Map.put("fixed_income_id", fixed_income.id)
      |> Map.put("ledger_id", ledger.id)
      |> Map.put("profile_id", profile_id)
      |> Map.put("date", Map.get(attrs, "date") || Date.utc_today())

    with {:ok, fi_transaction} <-
           FixedIncomeTransaction.system_changeset(%FixedIncomeTransaction{}, attrs)
           |> Repo.insert() do
      Finance.broadcast(:fixed_income_transaction, ledger.id, {:saved, fi_transaction})
      {:ok, fi_transaction}
    else
      {:error, changeset} ->
        {:error, changeset}
    end
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

  def generate_yields(%Ledger{} = ledger) do
    from(fi in FixedIncome,
      where: fi.ledger_id == ^ledger.id
    )
    |> Repo.all()
    |> Enum.each(fn fi -> generate_yield(fi, ledger) end)
  end

  defp generate_yield(%FixedIncome{} = fixed_income, %Ledger{} = ledger) do
    total_days_since_start = Date.diff(Date.utc_today(), fixed_income.start_date)

    fixed_income.yield_frequency
    |> case do
      :daily ->
        with yield <-
               compute_yield(
                 fixed_income.current_balance,
                 fixed_income.remuneration_rate,
                 1,
                 total_days_since_start,
                 0.149
               ) do
          attrs = %{
            "type" => :yield,
            "value" => Decimal.from_float(yield),
            "date" => Date.utc_today(),
            "description" => "Rendimento diário",
            "is_automatic" => true
          }

          create_transaction(fixed_income, attrs, ledger, fixed_income.profile_id)
        end

      :monthly ->
        if fixed_income.last_yield_date == nil or
             Date.diff(
               Date.utc_today(),
               fixed_income.last_yield_date || fixed_income.start_date
             ) >= 30 do
          diff =
            business_days_between(
              fixed_income.last_yield_date || fixed_income.start_date,
              Date.utc_today()
            )

          yield =
            compute_yield(
              fixed_income.current_balance,
              fixed_income.remuneration_rate,
              diff,
              total_days_since_start,
              0.149
            )

          attrs = %{
            "type" => :yield,
            "value" => Decimal.from_float(yield),
            "date" => Date.utc_today(),
            "description" => "Rendimento mensal",
            "is_automatic" => true
          }

          create_transaction(fixed_income, attrs, ledger, fixed_income.profile_id)
        else
          {:ok, nil}
        end

      _ ->
        {:error, "Unsupported yield frequency"}
    end
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

  def compute_yield(
        current_balance,
        remuneration_rate,
        days_to_compute,
        total_days_since_start,
        cdi_annual
      ) do
    daily_cdi_rate = :math.pow(1 + cdi_annual, 1 / 252) - 1
    daily_rate = daily_cdi_rate * (Decimal.to_float(remuneration_rate) / 100)
    gross_yield = current_balance * daily_rate * days_to_compute

    tax_rate =
      cond do
        total_days_since_start <= 180 -> 0.225
        total_days_since_start <= 360 -> 0.20
        total_days_since_start <= 720 -> 0.175
        true -> 0.15
      end

    net_yield = gross_yield * (1 - tax_rate)
    Float.round(net_yield, 2)
  end
end

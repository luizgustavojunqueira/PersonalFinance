defmodule PersonalFinance.Investment do
  @moduledoc """
  Context for managing investment operations, particularly fixed income investments.
  """

  alias PersonalFinance.Utils.DateUtils
  alias PersonalFinance.Utils.ParseUtils
  alias PersonalFinance.Repo
  alias PersonalFinance.Accounts.Scope
  alias PersonalFinance.Finance.{Ledger}
  alias PersonalFinance.Finance
  alias PersonalFinance.Investment.{FixedIncome, FixedIncomeTransaction, MarketRate}

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
        attrs
      ) do
    fixed_income
    |> FixedIncome.changeset(attrs, ledger.id)
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
  def create_fixed_income(attrs, %Ledger{} = ledger) do
    Repo.transaction(fn ->
      with {:ok, fixed_income} <- create_fixed_income_record(attrs, ledger),
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
  def calculate_balance(%FixedIncome{id: id, start_date: date}) do
    query =
      from t in FixedIncomeTransaction,
        where: t.fixed_income_id == ^id,
        where: t.date >= ^date,
        select: %{
          deposits:
            sum(fragment("CASE WHEN ? IN ('deposit') THEN ? ELSE 0 END", t.type, t.value)),
          withdrawals:
            sum(fragment("CASE WHEN ? IN ('withdraw') THEN ? ELSE 0 END", t.type, t.value)),
          yields: sum(fragment("CASE WHEN ? IN ('yield') THEN ? ELSE 0 END", t.type, t.value)),
          yield_taxes: sum(fragment("CASE WHEN ? IN ('yield') THEN ? ELSE 0 END", t.type, t.tax))
        }

    result = Repo.one(query)

    deposits = Decimal.new(result.deposits || 0)
    withdrawals = Decimal.new(result.withdrawals || 0)
    yields = Decimal.new(result.yields || 0)
    yield_taxes = Decimal.new(result.yield_taxes || 0)

    balance =
      deposits
      |> Decimal.add(yields)
      |> Decimal.sub(withdrawals)
      |> Decimal.sub(yield_taxes)
      |> Decimal.to_float()

    %{
      balance: Float.round(balance, 2),
      yields: if(balance == 0.00, do: 0.00, else: Decimal.to_float(yields)),
      yield_taxes: if(balance == 0.00, do: 0.00, else: Decimal.to_float(yield_taxes))
    }
  end

  @doc """
  Updates the cached balance of a fixed income investment.
  """
  def update_balance(%FixedIncome{} = fixed_income, %FixedIncomeTransaction{} = fi_transaction) do
    values = calculate_balance(fixed_income)

    attrs =
      %{
        current_balance: values.balance,
        total_tax_deducted: values.yield_taxes,
        total_yield: values.yields,
        last_yield_date:
          if(fi_transaction.type == :yield,
            do: fi_transaction.date,
            else: fixed_income.last_yield_date
          )
      }
      |> Map.merge(
        cond do
          values.balance == 0 ->
            %{is_active: false}

          values.balance > 0 and not fixed_income.is_active ->
            %{
              is_active: true,
              start_date: fi_transaction.date,
              initial_investment: values.balance,
              last_yield_date: nil,
              total_yield: 0,
              total_tax_deducted: 0
            }

          true ->
            %{}
        end
      )

    with {:ok, updated_fi} <-
           fixed_income
           |> FixedIncome.system_changeset(attrs)
           |> Repo.update() do
      fresh_fixed_income =
        Repo.get!(FixedIncome, updated_fi.id)
        |> Repo.preload(:profile)

      Finance.broadcast(:fixed_income, fresh_fixed_income.ledger_id, {:saved, fresh_fixed_income})
      {:ok, fresh_fixed_income}
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

  defp create_fixed_income_record(attrs, ledger) do
    with {:ok, fixed_income = %FixedIncome{}} <-
           change_fixed_income(%FixedIncome{}, ledger, attrs)
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

    dateTime = DateTime.new!(Date.utc_today(), Time.utc_now(), "Etc/UTC")

    attrs = %{
      "description" => "Investimento em #{fixed_income.name}",
      "value" => fixed_income.initial_investment,
      "total_value" => fixed_income.initial_investment,
      "amount" => 1,
      "type" => :expense,
      "category_id" => investment_category.id,
      "date_input" => dateTime |> DateTime.to_date(),
      "time_input" => dateTime |> DateUtils.to_local_time_with_date(),
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
      |> Map.put(
        "date",
        Map.get(attrs, "date") ||
          DateTime.new!(Date.utc_today(), Time.utc_now(), "Etc/UTC")
          |> DateTime.truncate(:second)
      )

    with {:ok, fi_transaction} <-
           FixedIncomeTransaction.system_changeset(%FixedIncomeTransaction{}, attrs)
           |> Repo.insert() do
      Finance.broadcast(
        :fixed_income_transaction,
        ledger.id,
        {:saved, fi_transaction},
        fixed_income.id
      )

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

      IO.inspect(description, label: "General Transaction Description")

      general_type =
        case fi_transaction.type do
          :deposit -> :expense
          :withdraw -> :income
        end

      IO.inspect(general_type, label: "General Transaction Type")

      investment_category = Finance.get_investment_category(%Scope{}, ledger.id)
      dateTime = DateTime.new!(Date.utc_today(), Time.utc_now(), "Etc/UTC")

      IO.inspect(investment_category, label: "Investment Category")

      attrs = %{
        "description" => description,
        "amount" => 1,
        "value" => Decimal.to_float(fi_transaction.value),
        "total_value" => Decimal.to_float(fi_transaction.value),
        "type" => general_type,
        "category_id" => investment_category.id,
        "date_input" => dateTime |> DateTime.to_date(),
        "time_input" => dateTime |> DateUtils.to_local_time_with_date(),
        "ledger_id" => ledger.id,
        "profile_id" => fi_transaction.profile_id,
        "time_input" =>
          fi_transaction.date
          |> DateUtils.to_local_time_with_date(),
        "date_input" =>
          fi_transaction.date
          |> DateTime.to_date()
      }

      IO.inspect(attrs)

      Finance.create_transaction(%Scope{}, attrs, ledger)
      |> case do
        {:ok, transaction} ->
          # Link the transactions
          fi_transaction
          |> FixedIncomeTransaction.changeset(%{transaction_id: transaction.id}, ledger.id)
          |> Repo.update()

          {:ok, transaction}

        error ->
          IO.inspect(error, label: "Error creating general transaction")
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
    if Date.utc_today() |> business_day?() do
      from(fi in FixedIncome,
        where: fi.ledger_id == ^ledger.id
      )
      |> Repo.all()
      |> Enum.each(fn fi -> generate_yield(fi, ledger) end)
    else
      IO.inspect("Hoje não é um dia útil, rendimentos não serão calculados.")
      {:ok, nil}
    end
  end

  defp generate_yield(%FixedIncome{} = fixed_income, %Ledger{} = ledger) do
    total_days_since_start = Date.diff(Date.utc_today(), fixed_income.start_date)

    today_cdi_rate =
      MarketRate
      |> where([mr], mr.type == :cdi and mr.date <= ^Date.utc_today())
      |> limit(1)
      |> Repo.one()

    daily_cdi_rate =
      if today_cdi_rate,
        do: Decimal.to_float(today_cdi_rate.value) / 100,
        else: 0.149 / 100 / 252

    fixed_income.yield_frequency
    |> case do
      :daily ->
        if fixed_income.last_yield_date == nil or
             Date.diff(
               Date.utc_today(),
               fixed_income.last_yield_date || fixed_income.start_date
             ) >= 0 do
          with yield <-
                 compute_yield(
                   fixed_income.current_balance,
                   fixed_income.remuneration_rate,
                   total_days_since_start,
                   :cdi,
                   daily_cdi_rate
                 ) do
            if yield.gross <= 0.00 do
              {:ok, nil}
            else
              attrs = %{
                "type" => :yield,
                "value" => Decimal.from_float(yield.gross),
                "tax" => Decimal.from_float(yield.tax),
                "date" => DateTime.new!(Date.utc_today(), Time.utc_now(), "Etc/UTC"),
                "description" => "Rendimento diário",
                "is_automatic" => true
              }

              create_transaction(fixed_income, attrs, ledger, fixed_income.profile_id)
            end
          end
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
      6 -> false
      7 -> false
      _ -> true
    end
  end

  def compute_yield(
        current_balance,
        remuneration_rate,
        total_days_since_start,
        :cdi,
        daily_cdi_rate
      ) do
    daily_rate = daily_cdi_rate * (Decimal.to_float(remuneration_rate) / 100)
    gross_yield = current_balance * daily_rate

    tax_rate =
      cond do
        total_days_since_start <= 180 -> 0.225
        total_days_since_start <= 360 -> 0.20
        total_days_since_start <= 720 -> 0.175
        true -> 0.15
      end

    %{
      gross: Float.round(gross_yield, 2),
      tax: Float.round(gross_yield * tax_rate, 2)
    }
  end

  def fetch_and_store_market_rates(type) do
    with {:ok, rates} <- fetch_market_rates(type) do
      Enum.each(rates, fn {type, date, value} ->
        attrs = %{
          "type" => type,
          "value" => Decimal.from_float(value),
          "date" => ParseUtils.parse_date(date)
        }

        %PersonalFinance.Investment.MarketRate{}
        |> PersonalFinance.Investment.MarketRate.changeset(attrs)
        |> Repo.insert()
      end)

      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_market_rates(type) when type in [:cdi, :ipca, :selic] do
    url =
      case type do
        :cdi -> "https://api.bcb.gov.br/dados/serie/bcdata.sgs.12/dados/ultimos/1?formato=json"
        :ipca -> "https://api.bcb.gov.br/dados/serie/bcdata.sgs.433/dados/ultimos/1?formato=json"
        :selic -> "https://api.bcb.gov.br/dados/serie/bcdata.sgs.11/dados/ultimos/1?formato=json"
      end

    case Req.get(url) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        case body do
          [%{"valor" => value, "data" => date} | _] ->
            {:ok, [{type, date, ParseUtils.parse_float(value)}]}

          _ ->
            {:error, "Unexpected response format for #{type}"}
        end

      {:ok, %Req.Response{status: status}} ->
        {:error, "Failed to fetch market rate for #{type}, status: #{status}"}

      {:error, reason} ->
        {:error, "HTTP request failed for #{type}: #{inspect(reason)}"}
    end
  end

  defp fetch_market_rates(nil) do
    types = [:cdi, :ipca, :selic]

    results =
      types
      |> Enum.map(&fetch_market_rates/1)

    if Enum.all?(results, fn res -> match?({:ok, _}, res) end) do
      {:ok,
       results
       |> Enum.flat_map(fn {:ok, rates} -> rates end)}
    else
      {:error, "Failed to fetch some market rates"}
    end
  end

  def get_total_invested(ledger_id) do
    total_balance =
      from(fi in FixedIncome,
        where: fi.ledger_id == ^ledger_id and fi.is_active == true,
        select: %{
          total_balance: sum(fi.current_balance)
        }
      )
      |> Repo.one()
      |> case do
        nil -> 0.0
        result -> result.total_balance || 0.0
      end

    {total_deposited, total_withdrawed} =
      from(t in FixedIncomeTransaction,
        where: t.ledger_id == ^ledger_id,
        select: %{
          total_deposited:
            sum(fragment("CASE WHEN ? = 'deposit' THEN ? ELSE 0 END", t.type, t.value)),
          total_withdrawed:
            sum(fragment("CASE WHEN ? = 'withdraw' THEN ? ELSE 0 END", t.type, t.value))
        }
      )
      |> Repo.one()
      |> case do
        nil ->
          {Decimal.new(0), Decimal.new(0)}

        result ->
          {result.total_deposited || Decimal.new(0), result.total_withdrawed || Decimal.new(0)}
      end

    %{
      total_invested:
        Decimal.to_float(total_deposited) -
          Decimal.to_float(total_withdrawed),
      total_balance: total_balance
    }
  end

  def get_details(%FixedIncome{} = fixed_income) do
    balance_info = calculate_balance(fixed_income)

    {
      fixed_income.initial_investment +
        balance_info.yields -
        balance_info.yield_taxes,
      balance_info.yields,
      balance_info.yield_taxes,
      balance_info.balance
    }
  end
end

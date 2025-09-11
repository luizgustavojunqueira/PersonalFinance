defmodule PersonalFinance.Balance do
  alias PersonalFinance.Utils.DateUtils
  alias PersonalFinance.Finance
  alias PersonalFinance.Repo
  alias PersonalFinance.Accounts.Scope

  alias PersonalFinance.Finance.{
    Transaction
  }

  import Ecto.Query

  @doc """
  Get sum of transactions in a ledger for a specific profile.
  """
  def get_sum_transactions(
        %Scope{} = scope,
        ledger_id,
        type,
        profile_id \\ nil,
        {date_start, date_end} \\ {nil, nil},
        all_categories \\ false
      ) do
    category_id =
      if type == :expense do
        nil
      else
        Finance.get_category_by_name("Sem Categoria", scope, ledger_id)
        |> case do
          nil -> nil
          category -> category.id
        end
      end

    base_query =
      from(t in Transaction,
        where: t.ledger_id == ^ledger_id and t.type == ^type,
        select: sum(t.total_value)
      )

    query_with_category =
      if not all_categories and category_id do
        from(t in base_query, where: t.category_id == ^category_id)
      else
        base_query
      end

    query_with_profile =
      if(profile_id,
        do: from(t in query_with_category, where: t.profile_id == ^profile_id),
        else: query_with_category
      )

    query_with_date =
      if date_start && date_end do
        from(t in query_with_profile,
          where: t.date >= ^date_start and t.date <= ^date_end
        )
      else
        query_with_profile
      end

    Repo.one(query_with_date)
    |> case do
      nil -> 0.0
      value -> value
    end
  end

  @doc """
  Get balance for a period in a ledger for a specific profile.
  """
  def get_balance(scope, ledger_id, period, profile_id \\ nil)

  def get_balance(%Scope{} = scope, ledger_id, :monthly, profile_id) do
    today = Date.utc_today()
    month_start = Date.beginning_of_month(today) |> DateUtils.to_date_time()
    month_end = Date.end_of_month(today) |> DateUtils.to_end_of_day_datetime()

    total_incomes_all_categories =
      get_sum_transactions(scope, ledger_id, :income, profile_id, {month_start, month_end}, true)

    total_incomes_no_category =
      get_sum_transactions(scope, ledger_id, :income, profile_id, {month_start, month_end})

    total_expenses =
      get_sum_transactions(scope, ledger_id, :expense, profile_id, {month_start, month_end})

    %{
      total_incomes: total_incomes_no_category,
      total_incomes_all_categories: total_incomes_all_categories,
      total_expenses: total_expenses,
      balance: total_incomes_no_category - total_expenses
    }
  end

  def get_balance(%Scope{} = scope, ledger_id, :yearly, profile_id) do
    today = Date.utc_today()
    year_start = Date.new(today.year, 1, 1)
    year_end = Date.new(today.year, 12, 31)

    total_incomes =
      get_sum_transactions(scope, ledger_id, :income, profile_id, {year_start, year_end})

    total_expenses =
      get_sum_transactions(scope, ledger_id, :expense, profile_id, {year_start, year_end})

    %{
      total_incomes: total_incomes,
      total_expenses: total_expenses,
      balance: total_incomes - total_expenses
    }
  end

  def get_balance(%Scope{} = scope, ledger_id, :all, profile_id) do
    total_incomes =
      get_sum_transactions(scope, ledger_id, :income, profile_id)

    total_expenses =
      get_sum_transactions(scope, ledger_id, :expense, profile_id)

    %{
      total_incomes: total_incomes,
      total_expenses: total_expenses,
      balance: total_incomes - total_expenses
    }
  end
end

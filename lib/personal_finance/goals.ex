defmodule PersonalFinance.Goals do
  @moduledoc """
  Goals context handles savings/investment targets and their link to fixed income assets.
  """

  import Ecto.Query
  alias PersonalFinance.Repo

  alias PersonalFinance.Goals.{Goal, GoalFixedIncome}
  alias PersonalFinance.Investment.{FixedIncome, FixedIncomeTransaction}

  @default_lookback_days 30

  def list_goals(_scope, ledger_id, opts \\ []) do
    preload = Keyword.get(opts, :preload, [:fixed_incomes, :profile])

    Goal
    |> where([g], g.ledger_id == ^ledger_id)
    |> order_by([g], desc: g.inserted_at)
    |> Repo.all()
    |> Repo.preload(preload)
  end

  def get_goal!(_scope, id, ledger_id, opts \\ []) do
    preload = Keyword.get(opts, :preload, [:fixed_incomes, :profile])

    Goal
    |> where([g], g.id == ^id and g.ledger_id == ^ledger_id)
    |> Repo.one!()
    |> Repo.preload(preload)
  end

  def create_goal(_scope, attrs, ledger_id) do
    %Goal{}
    |> Goal.changeset(attrs)
    |> Ecto.Changeset.put_change(:ledger_id, ledger_id)
    |> Repo.insert()
  end

  def update_goal(%Goal{} = goal, attrs) do
    goal
    |> Goal.changeset(attrs)
    |> Repo.update()
  end

  def delete_goal(%Goal{} = goal) do
    Repo.delete(goal)
  end

  def sync_fixed_incomes(%Goal{} = goal, fixed_income_ids) when is_list(fixed_income_ids) do
    allowed_ids = available_fixed_income_ids(goal.id, goal.ledger_id)

    scoped_ids =
      fixed_income_ids
      |> Enum.uniq()
      |> Enum.filter(&(&1 in allowed_ids))

    Repo.transaction(fn ->
      if scoped_ids != Enum.uniq(fixed_income_ids) do
        Repo.rollback(:invalid_fixed_income_selection)
      end

      Repo.delete_all(from gfi in GoalFixedIncome, where: gfi.goal_id == ^goal.id)

      Enum.each(scoped_ids, fn fixed_income_id ->
        case %GoalFixedIncome{}
             |> GoalFixedIncome.changeset(%{
               goal_id: goal.id,
               fixed_income_id: fixed_income_id
             })
             |> Repo.insert() do
          {:ok, _record} -> :ok
          {:error, reason} -> Repo.rollback(reason)
        end
      end)

      goal
      |> Repo.preload([:fixed_incomes, :profile])
    end)
  end

  def available_fixed_income_ids(goal_id \\ nil, ledger_id) do
    base_query =
      from gfi in GoalFixedIncome,
        join: g in Goal,
        on: g.id == gfi.goal_id,
        where: g.ledger_id == ^ledger_id

    taken_ids_query =
      case goal_id do
        nil -> from q in base_query, select: q.fixed_income_id
        _ -> from q in base_query, where: q.goal_id != ^goal_id, select: q.fixed_income_id
      end

    taken_ids = Repo.all(taken_ids_query) |> MapSet.new()

    from(fi in FixedIncome,
      where: fi.ledger_id == ^ledger_id,
      select: fi.id
    )
    |> Repo.all()
    |> Enum.reject(&(&1 in taken_ids))
  end

  def forecast(%Goal{} = goal, ledger_id, opts \\ []) do
    lookback_days = Keyword.get(opts, :lookback_days, @default_lookback_days)
    goal_with_fis = Repo.preload(goal, :fixed_incomes)

    current_total =
      goal_with_fis.fixed_incomes
      |> Enum.map(&decimal_from_float(&1.current_balance))
      |> Enum.reduce(Decimal.new("0"), &Decimal.add/2)

    remaining =
      goal_with_fis.target_amount
      |> Decimal.sub(current_total)
      |> clamp_zero()

    avg_daily_yield = average_daily_yield(goal_with_fis.fixed_incomes, ledger_id, lookback_days)

    forecast_days =
      case Decimal.compare(avg_daily_yield, 0) do
        :gt -> Decimal.div(remaining, avg_daily_yield)
        _ -> nil
      end

    forecast_date =
      case forecast_days do
        %Decimal{} = days ->
          days
          |> Decimal.to_float()
          |> Float.ceil()
          |> trunc()
          |> then(&Date.add(Date.utc_today(), &1))

        _ -> nil
      end

    %{
      current_total: current_total,
      remaining: remaining,
      average_daily_yield: avg_daily_yield,
      forecast_days: forecast_days,
      forecast_date: forecast_date
    }
  end

  defp average_daily_yield([], _ledger_id, _lookback_days), do: Decimal.new("0")

  defp average_daily_yield(fixed_incomes, ledger_id, lookback_days) do
    ids = Enum.map(fixed_incomes, & &1.id)

    {start_datetime, end_datetime} = yield_window(lookback_days)

    query =
      from t in FixedIncomeTransaction,
        where:
          t.ledger_id == ^ledger_id and t.type == :yield and t.fixed_income_id in ^ids and
            t.date >= ^start_datetime and t.date <= ^end_datetime,
        select: t.value

    total_yield =
      query
      |> Repo.all()
      |> Enum.reduce(Decimal.new("0"), &Decimal.add/2)

    Decimal.div(total_yield, Decimal.new(max(lookback_days, 1)))
  end

  defp clamp_zero(%Decimal{} = decimal) do
    if Decimal.compare(decimal, 0) == :lt, do: Decimal.new("0"), else: decimal
  end

  defp yield_window(lookback_days) do
    end_date = Date.utc_today()
    start_date = Date.add(end_date, -lookback_days)

    start_datetime = DateTime.new!(start_date, ~T[00:00:00], "Etc/UTC")
    end_datetime = DateTime.new!(end_date, ~T[23:59:59], "Etc/UTC")

    {start_datetime, end_datetime}
  end

  defp decimal_from_float(nil), do: Decimal.new("0")

  defp decimal_from_float(float) when is_float(float) do
    float
    |> Decimal.from_float()
    |> Decimal.round(6)
  end

  defp decimal_from_float(int) when is_integer(int), do: Decimal.new(int)
  defp decimal_from_float(%Decimal{} = decimal), do: decimal
end

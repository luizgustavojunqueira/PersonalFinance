defmodule PersonalFinance.Math.Retirement do
  @moduledoc """
  Financial Independence and Retirement projection calculations.
  """

  @type fi_params :: %{
          required(:monthly_expenses) => number(),
          required(:withdrawal_rate) => number(),
          required(:current_wealth) => number(),
          required(:monthly_contribution) => number(),
          required(:return_rate) => number(),
          optional(:max_years) => pos_integer()
        }

  @type retirement_params :: %{
          required(:years_to_retirement) => pos_integer(),
          required(:current_wealth) => number(),
          required(:monthly_contribution) => number(),
          required(:accumulation_rate) => number(),
          required(:retirement_rate) => number(),
          required(:strategy) => :perpetual | :consume,
          optional(:lifespan_years) => pos_integer()
        }

  @type timeline_point :: %{
          period: pos_integer(),
          balance: float(),
          contributions: float(),
          earnings: float()
        }

  @type fi_result :: %{
          target_wealth: float(),
          monthly_passive_income: float(),
          years_to_fi: float() | nil,
          months_to_fi: pos_integer() | nil,
          final_balance: float(),
          total_contributed: float(),
          total_earnings: float(),
          current_progress: float(),
          timeline: list(timeline_point()),
          timeline_with_withdrawals: list(timeline_point()) | nil
        }

  @type retirement_result :: %{
          wealth_at_retirement: float(),
          total_contributed: float(),
          total_earnings: float(),
          monthly_income_perpetual: float(),
          monthly_income_consume: float() | nil,
          accumulation_timeline: list(timeline_point()),
          retirement_timeline: list(timeline_point()) | nil
        }

  @doc """
  Calculate Financial Independence projection.

  ## Examples

      iex> PersonalFinance.Math.Retirement.calculate_fi(%{
      ...>   monthly_expenses: 5000,
      ...>   withdrawal_rate: 4.0,
      ...>   current_wealth: 100_000,
      ...>   monthly_contribution: 2000,
      ...>   return_rate: 0.8,
      ...>   max_years: 50
      ...> })
      %{target_wealth: 1_500_000, years_to_fi: 18.6, ...}
  """
  @spec calculate_fi(fi_params()) :: fi_result() | nil
  def calculate_fi(params) do
    monthly_expenses = to_float(params.monthly_expenses)
    withdrawal_rate = to_float(params.withdrawal_rate) / 100.0
    current_wealth = to_float(params.current_wealth)
    monthly_contribution = to_float(params.monthly_contribution)
    monthly_return = to_float(params.return_rate) / 100.0
    max_years = params[:max_years] || 50

    if monthly_expenses <= 0 or withdrawal_rate <= 0 or monthly_contribution < 0 or monthly_return < 0 do
      nil
    else
      # Target wealth using the 4% rule (or custom withdrawal rate)
      annual_expenses = monthly_expenses * 12
      target_wealth = annual_expenses / withdrawal_rate

      # Monthly passive income at FI
      monthly_passive_income = monthly_expenses

      # Simulate accumulation
      max_months = max_years * 12
      {timeline, final_balance, total_contributed, months_to_fi} =
        simulate_accumulation(current_wealth, monthly_contribution, monthly_return, max_months, target_wealth)

      years_to_fi = if months_to_fi, do: months_to_fi / 12.0, else: nil
      total_earnings = final_balance - current_wealth - total_contributed
      current_progress = if target_wealth > 0, do: current_wealth / target_wealth * 100.0, else: 0.0

      # Calculate timeline with withdrawals after FI
      timeline_with_withdrawals =
        if months_to_fi do
          simulate_fi_with_withdrawals(
            timeline,
            months_to_fi,
            monthly_expenses,
            monthly_contribution,
            monthly_return,
            max_months
          )
        else
          nil
        end

      %{
        target_wealth: target_wealth,
        monthly_passive_income: monthly_passive_income,
        years_to_fi: years_to_fi,
        months_to_fi: months_to_fi,
        current_wealth: current_wealth,
        final_balance: final_balance,
        total_contributed: total_contributed,
        total_earnings: total_earnings,
        current_progress: current_progress,
        timeline: timeline,
        timeline_with_withdrawals: timeline_with_withdrawals
      }
    end
  end

  @doc """
  Calculate retirement projection with fixed time horizon.
  """
  @spec calculate_retirement(retirement_params()) :: retirement_result() | nil
  def calculate_retirement(params) do
    years_to_retirement = to_int(params.years_to_retirement)
    current_wealth = to_float(params.current_wealth)
    monthly_contribution = to_float(params.monthly_contribution)
    monthly_accumulation_rate = to_float(params.accumulation_rate) / 100.0
    monthly_retirement_rate = to_float(params.retirement_rate) / 100.0
    strategy = params.strategy || :perpetual
    lifespan_years = params[:lifespan_years] || 30

    if years_to_retirement <= 0 or monthly_contribution < 0 or monthly_accumulation_rate < 0 or monthly_retirement_rate < 0 do
      nil
    else
      # Accumulation phase
      months_to_retirement = years_to_retirement * 12
      {accumulation_timeline, wealth_at_retirement, total_contributed, _} =
        simulate_accumulation(current_wealth, monthly_contribution, monthly_accumulation_rate, months_to_retirement, nil)

      total_earnings = wealth_at_retirement - current_wealth - total_contributed

      # Retirement income calculations
      monthly_income_perpetual = wealth_at_retirement * monthly_retirement_rate

      {monthly_income_consume, retirement_timeline} =
        case strategy do
          :consume ->
            lifespan_months = lifespan_years * 12
            monthly_income = calculate_pmt(wealth_at_retirement, monthly_retirement_rate, lifespan_months)
            timeline = simulate_consumption(wealth_at_retirement, monthly_income, monthly_retirement_rate, lifespan_months)
            {monthly_income, timeline}

          _ ->
            {nil, nil}
        end

      %{
        wealth_at_retirement: wealth_at_retirement,
        total_contributed: total_contributed,
        total_earnings: total_earnings,
        monthly_income_perpetual: monthly_income_perpetual,
        monthly_income_consume: monthly_income_consume,
        accumulation_timeline: accumulation_timeline,
        retirement_timeline: retirement_timeline
      }
    end
  end

  # Private helpers

  defp simulate_fi_with_withdrawals(accumulation_timeline, months_to_fi, monthly_withdrawal, monthly_contribution, rate, _max_months) do
    # Get the exact FI point or the closest point before it
    fi_point = Enum.find(accumulation_timeline, fn p -> p.period >= months_to_fi end)

    if fi_point do
      initial_wealth = fi_point.balance - fi_point.contributions

      # Calculate the exact balance at FI moment (not at fi_point which might be later)
      # Find the point right before FI
      previous_point = Enum.reverse(accumulation_timeline)
        |> Enum.find(fn p -> p.period < months_to_fi end)

      # If FI happens between snapshots, calculate exact balance at FI
      balance_at_fi = if previous_point && previous_point.period < months_to_fi do
        months_from_previous = months_to_fi - previous_point.period
        Enum.reduce(1..months_from_previous, previous_point.balance, fn _, balance ->
          earnings = balance * rate
          balance + earnings + monthly_contribution  # Still contributing until FI
        end)
      else
        fi_point.balance
      end

      # Build new timeline matching the original but with withdrawals after FI
      Enum.map(accumulation_timeline, fn point ->
        if point.period < months_to_fi do
          # Before FI: same as accumulation
          point
        else
          # At or after FI: recalculate from exact FI balance with withdrawals
          months_after_fi = point.period - months_to_fi

          # Simulate from FI balance with withdrawals
          final_balance =
            Enum.reduce(1..months_after_fi, balance_at_fi, fn _, balance ->
              earnings = balance * rate
              balance + earnings - monthly_withdrawal
            end)

          %{
            period: point.period,
            balance: final_balance,
            contributions: fi_point.contributions,
            earnings: final_balance - initial_wealth - fi_point.contributions
          }
        end
      end)
    else
      accumulation_timeline
    end
  end

  defp simulate_accumulation(initial, contribution, rate, max_months, target) do
    Enum.reduce_while(1..max_months, {[], initial, 0.0, nil}, fn month, {timeline, balance, contributed, reached} ->
      new_contributed = contributed + contribution
      earnings = balance * rate
      new_balance = balance + contribution + earnings

      point = %{
        period: month,
        balance: new_balance,
        contributions: new_contributed,
        earnings: new_balance - initial - new_contributed
      }

      new_reached = if target && is_nil(reached) && new_balance >= target, do: month, else: reached

      # Store yearly snapshots or every month if < 24 months
      should_store = month == 1 || rem(month, 12) == 0 || max_months <= 24 || month == max_months

      new_timeline = if should_store, do: timeline ++ [point], else: timeline

      {:cont, {new_timeline, new_balance, new_contributed, new_reached}}
    end)
    |> then(fn {timeline, balance, contributed, reached} ->
      {timeline, balance, contributed, reached}
    end)
  end

  defp simulate_consumption(initial, monthly_withdrawal, rate, max_months) do
    Enum.reduce_while(1..max_months, {[], initial}, fn month, {timeline, balance} ->
      earnings = balance * rate
      new_balance = balance + earnings - monthly_withdrawal

      point = %{
        period: month,
        balance: max(new_balance, 0.0),
        withdrawal: monthly_withdrawal,
        earnings: earnings
      }

      # Store yearly snapshots
      should_store = month == 1 || rem(month, 12) == 0 || month == max_months

      new_timeline = if should_store, do: timeline ++ [point], else: timeline

      if new_balance <= 0 do
        {:halt, {new_timeline, 0.0}}
      else
        {:cont, {new_timeline, new_balance}}
      end
    end)
    |> then(fn {timeline, _balance} -> timeline end)
  end

  # PMT formula for loan/annuity payment
  defp calculate_pmt(present_value, rate, periods) when rate > 0 do
    factor = :math.pow(1.0 + rate, periods)
    present_value * (rate * factor) / (factor - 1.0)
  end

  defp calculate_pmt(present_value, _rate, periods) when periods > 0 do
    present_value / periods
  end

  defp calculate_pmt(_present_value, _rate, _periods), do: 0.0

  defp to_float(nil), do: 0.0
  defp to_float(v) when is_integer(v), do: v * 1.0
  defp to_float(v) when is_float(v), do: v

  defp to_float(v) when is_binary(v) do
    case Float.parse(v) do
      {num, _} -> num
      :error -> 0.0
    end
  end

  defp to_int(nil), do: 0
  defp to_int(v) when is_integer(v), do: v

  defp to_int(v) when is_binary(v) do
    case Integer.parse(v) do
      {num, _} -> num
      :error -> 0
    end
  end

  defp to_int(v) when is_float(v), do: trunc(v)
end

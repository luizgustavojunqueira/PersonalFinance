defmodule PersonalFinance.Math.Investments do
  @moduledoc """
  Pure calculation helpers for investment simulations (interest, contributions, etc).
  """

  @type rate_period :: :month | :year
  @type duration_unit :: :month | :year

  @type simulation_params :: %{
          required(:principal) => number(),
          required(:rate) => number(),
          required(:rate_period) => rate_period(),
          required(:duration) => pos_integer(),
          required(:duration_unit) => duration_unit(),
          optional(:monthly_contribution) => number(),
          optional(:simple_interest) => boolean()
        }

  @type timeline_point :: %{
          period: pos_integer(),
          balance: float(),
          invested: float(),
          interest: float(),
          delta_interest: float()
        }

  @type simulation_result :: %{
          final_balance: float(),
          total_invested: float(),
          total_interest: float(),
          timeline: [timeline_point()]
        }

  @spec simulate(simulation_params()) :: simulation_result()
  def simulate(params) do
    principal = to_float(params.principal)
    rate = to_float(params.rate) / 100.0
    rate_period = params.rate_period || :month
    duration = to_int(params.duration)
    duration_unit = params.duration_unit || :month
    monthly_contribution = to_float(params[:monthly_contribution] || 0)
    simple_interest? = params[:simple_interest] || false

    total_months =
      case {duration_unit, duration} do
        {:year, d} when d > 0 -> d * 12
        {:month, d} when d > 0 -> d
        _ -> 0
      end

    if total_months <= 0 or rate < 0 do
      %{
        final_balance: principal,
        total_invested: principal + monthly_contribution * max(duration, 0),
        total_interest: 0.0,
        timeline: []
      }
    else
      monthly_rate =
        case rate_period do
          :month -> rate
          :year -> :math.pow(1.0 + rate, 1.0 / 12.0) - 1.0
        end

      {timeline, final_balance, total_invested, total_interest} =
        build_timeline(
          principal,
          monthly_rate,
          monthly_contribution,
          total_months,
          simple_interest?
        )

      %{
        final_balance: final_balance,
        total_invested: total_invested,
        total_interest: total_interest,
        timeline: timeline
      }
    end
  end

  defp build_timeline(
         principal,
         monthly_rate,
         monthly_contribution,
         total_months,
         simple_interest?
       ) do
    Enum.reduce(1..total_months, {[], principal, principal, 0.0, 0.0}, fn period,
                                                                          {acc, balance, invested,
                                                                           total_interest,
                                                                           _prev_interest} ->
      {new_balance, new_invested, new_total_interest} =
        apply_period(
          balance,
          invested,
          total_interest,
          monthly_rate,
          monthly_contribution,
          simple_interest?,
          period
        )

      delta_interest = new_total_interest - total_interest

      point = %{
        period: period,
        balance: new_balance,
        invested: new_invested,
        interest: new_total_interest,
        delta_interest: delta_interest
      }

      {[point | acc], new_balance, new_invested, new_total_interest, new_total_interest}
    end)
    |> then(fn {timeline, balance, invested, total_interest, _} ->
      {Enum.reverse(timeline), balance, invested, total_interest}
    end)
  end

  defp apply_period(
         _balance,
         invested,
         total_interest,
         monthly_rate,
         monthly_contribution,
         true,
         _period
       ) do
    simple_principal = invested
    interest_this_period = simple_principal * monthly_rate

    new_total_interest = total_interest + interest_this_period
    new_invested = invested + monthly_contribution
    new_balance = simple_principal + new_total_interest + (new_invested - simple_principal)

    {new_balance, new_invested, new_total_interest}
  end

  defp apply_period(
         balance,
         invested,
         total_interest,
         monthly_rate,
         monthly_contribution,
         false,
         _period
       ) do
    interest_this_period = balance * monthly_rate
    new_balance = balance + interest_this_period + monthly_contribution
    new_invested = invested + monthly_contribution
    new_total_interest = total_interest + interest_this_period

    {new_balance, new_invested, new_total_interest}
  end

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

  @doc """
  Goal seeker: calculates the required rate of return to reach a target.

  Returns the monthly and annual rates needed.
  """
  @spec calculate_required_rate(%{
          required(:target) => number(),
          required(:principal) => number(),
          required(:monthly_contribution) => number(),
          required(:duration) => pos_integer(),
          required(:duration_unit) => duration_unit()
        }) :: %{monthly_rate: float(), annual_rate: float()} | nil
  def calculate_required_rate(params) do
    target = to_float(params.target)
    principal = to_float(params.principal)
    monthly_contribution = to_float(params.monthly_contribution)
    duration = to_int(params.duration)
    duration_unit = params.duration_unit || :month

    total_months =
      case {duration_unit, duration} do
        {:year, d} when d > 0 -> d * 12
        {:month, d} when d > 0 -> d
        _ -> 0
      end

    if total_months <= 0 or target <= principal do
      nil
    else
      monthly_rate =
        find_rate_binary_search(
          target,
          principal,
          monthly_contribution,
          total_months,
          0.0,
          1.0,
          0.00001
        )

      if monthly_rate do
        annual_rate = :math.pow(1.0 + monthly_rate, 12.0) - 1.0
        %{monthly_rate: monthly_rate * 100.0, annual_rate: annual_rate * 100.0}
      else
        nil
      end
    end
  end

  defp find_rate_binary_search(
         target,
         principal,
         monthly_contribution,
         months,
         low,
         high,
         tolerance
       ) do
    find_rate_binary_search(
      target,
      principal,
      monthly_contribution,
      months,
      low,
      high,
      tolerance,
      0
    )
  end

  defp find_rate_binary_search(
         _target,
         _principal,
         _monthly_contribution,
         _months,
         low,
         high,
         _tolerance,
         iterations
       )
       when iterations > 100 do
    (low + high) / 2.0
  end

  defp find_rate_binary_search(
         target,
         principal,
         monthly_contribution,
         months,
         low,
         high,
         tolerance,
         iterations
       ) do
    mid = (low + high) / 2.0

    {_, final_balance, _, _} = build_timeline(principal, mid, monthly_contribution, months, false)

    diff = final_balance - target

    cond do
      abs(diff) < tolerance ->
        mid

      diff > 0 ->
        find_rate_binary_search(
          target,
          principal,
          monthly_contribution,
          months,
          low,
          mid,
          tolerance,
          iterations + 1
        )

      true ->
        find_rate_binary_search(
          target,
          principal,
          monthly_contribution,
          months,
          mid,
          high,
          tolerance,
          iterations + 1
        )
    end
  end

  @doc """
  Calculates the required monthly contribution to reach a target.
  """
  @spec calculate_required_contribution(%{
          required(:target) => number(),
          required(:principal) => number(),
          required(:rate) => number(),
          required(:rate_period) => rate_period(),
          required(:duration) => pos_integer(),
          required(:duration_unit) => duration_unit()
        }) :: float() | nil
  def calculate_required_contribution(params) do
    target = to_float(params.target)
    principal = to_float(params.principal)
    rate = to_float(params.rate) / 100.0
    rate_period = params.rate_period || :month
    duration = to_int(params.duration)
    duration_unit = params.duration_unit || :month

    total_months =
      case {duration_unit, duration} do
        {:year, d} when d > 0 -> d * 12
        {:month, d} when d > 0 -> d
        _ -> 0
      end

    monthly_rate =
      case rate_period do
        :month -> rate
        :year -> :math.pow(1.0 + rate, 1.0 / 12.0) - 1.0
      end

    if total_months <= 0 or target <= principal do
      nil
    else
      find_contribution_binary_search(
        target,
        principal,
        monthly_rate,
        total_months,
        0.0,
        target,
        0.01
      )
    end
  end

  defp find_contribution_binary_search(
         target,
         principal,
         monthly_rate,
         months,
         low,
         high,
         tolerance
       ) do
    find_contribution_binary_search(
      target,
      principal,
      monthly_rate,
      months,
      low,
      high,
      tolerance,
      0
    )
  end

  defp find_contribution_binary_search(
         _target,
         _principal,
         _monthly_rate,
         _months,
         low,
         high,
         _tolerance,
         iterations
       )
       when iterations > 100 do
    (low + high) / 2.0
  end

  defp find_contribution_binary_search(
         target,
         principal,
         monthly_rate,
         months,
         low,
         high,
         tolerance,
         iterations
       ) do
    mid = (low + high) / 2.0

    {_, final_balance, _, _} = build_timeline(principal, monthly_rate, mid, months, false)

    diff = final_balance - target

    cond do
      abs(diff) < tolerance ->
        mid

      diff > 0 ->
        find_contribution_binary_search(
          target,
          principal,
          monthly_rate,
          months,
          low,
          mid,
          tolerance,
          iterations + 1
        )

      true ->
        find_contribution_binary_search(
          target,
          principal,
          monthly_rate,
          months,
          mid,
          high,
          tolerance,
          iterations + 1
        )
    end
  end
end

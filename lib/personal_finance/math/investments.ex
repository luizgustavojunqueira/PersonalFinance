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
        build_timeline(principal, monthly_rate, monthly_contribution, total_months, simple_interest?)

      %{
        final_balance: final_balance,
        total_invested: total_invested,
        total_interest: total_interest,
        timeline: timeline
      }
    end
  end

  defp build_timeline(principal, monthly_rate, monthly_contribution, total_months, simple_interest?) do
    Enum.reduce(1..total_months, {[], principal, principal, 0.0, 0.0}, fn period,
                                                                          {acc, balance, invested, total_interest, _prev_interest} ->
      {new_balance, new_invested, new_total_interest} =
        apply_period(balance, invested, total_interest, monthly_rate, monthly_contribution, simple_interest?, period)

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

  defp apply_period(_balance, invested, total_interest, monthly_rate, monthly_contribution, true, _period) do
    # Simple interest: interest only on initial principal (invested at period 0)
    simple_principal = invested
    interest_this_period = simple_principal * monthly_rate

    new_total_interest = total_interest + interest_this_period
    new_invested = invested + monthly_contribution
    new_balance = simple_principal + new_total_interest + (new_invested - simple_principal)

    {new_balance, new_invested, new_total_interest}
  end

  defp apply_period(balance, invested, total_interest, monthly_rate, monthly_contribution, false, _period) do
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
end

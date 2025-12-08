defmodule PersonalFinance.Math.Valuation do
  @moduledoc """
  Present/Future value calculations for single cash flows.
  """

  alias PersonalFinance.Utils.ParseUtils, as: Parse

  @type rate_period :: :month | :year
  @type duration_unit :: :month | :year

  @type params :: %{
          required(:mode) => :pv | :fv,
          required(:amount) => number(),
          required(:rate) => number(),
          required(:rate_period) => rate_period(),
          required(:duration) => pos_integer(),
          required(:duration_unit) => duration_unit()
        }

  @type timeline_point :: %{period: pos_integer(), balance: float()}

  @type result :: %{
          present_value: float(),
          future_value: float(),
          total_interest: float(),
          discount_factor: float(),
          timeline: list(timeline_point())
        }

  @spec calculate(params()) :: result() | nil
  def calculate(params) do
    mode = params.mode || :pv
    amount = Parse.parse_float(params.amount)
    rate = Parse.parse_float(params.rate) / 100.0
    rate_period = params.rate_period || :month
    duration = Parse.parse_int(params.duration)
    duration_unit = params.duration_unit || :month

    total_months = to_months(duration, duration_unit)

    cond do
      total_months <= 0 -> nil
      amount <= 0 -> nil
      rate < 0 -> nil
      true ->
        monthly_rate = to_monthly_rate(rate, rate_period)
        growth_factor = :math.pow(1.0 + monthly_rate, total_months)

        {present_value, future_value} =
          case mode do
            :pv ->
              fv = amount
              pv = fv / growth_factor
              {pv, fv}

            :fv ->
              pv = amount
              fv = pv * growth_factor
              {pv, fv}
          end

        total_interest = future_value - present_value
        timeline = build_timeline(present_value, monthly_rate, total_months)

        %{
          present_value: present_value,
          future_value: future_value,
          total_interest: total_interest,
          discount_factor: growth_factor,
          timeline: timeline
        }
    end
  end

  defp build_timeline(start_balance, monthly_rate, total_months) do
    Enum.reduce(1..total_months, {[%{period: 0, balance: start_balance}], start_balance}, fn period,
                                                                                              {acc, balance} ->
      new_balance = balance * (1.0 + monthly_rate)

      point = %{
        period: period,
        balance: new_balance
      }

      {[point | acc], new_balance}
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  defp to_monthly_rate(rate, :month), do: rate

  defp to_monthly_rate(rate, :year) do
    :math.pow(1.0 + rate, 1.0 / 12.0) - 1.0
  end

  defp to_months(duration, :year), do: max(duration, 0) * 12
  defp to_months(duration, :month), do: max(duration, 0)

end

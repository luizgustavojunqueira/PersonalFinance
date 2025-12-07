defmodule PersonalFinance.Math.Loans do
  @moduledoc """
  Financing and loan helpers (Price system).
  """

  @type rate_period :: :month | :year
  @type duration_unit :: :month | :year

  @type price_params :: %{
          required(:principal) => number(),
          required(:rate) => number(),
          required(:rate_period) => rate_period(),
          required(:duration) => pos_integer(),
          required(:duration_unit) => duration_unit()
        }

  @type schedule_row :: %{
          period: pos_integer(),
          payment: float(),
          interest: float(),
          amortization: float(),
          balance: float()
        }

  @spec price_amortization(price_params()) :: %{payment: float(), total_paid: float(), total_interest: float(), schedule: [schedule_row()]} | nil
  def price_amortization(params) do
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
      case {rate_period, rate} do
        {_period, r} when r <= 0 -> 0.0
        {:month, r} -> r
        {:year, r} -> :math.pow(1.0 + r, 1.0 / 12.0) - 1.0
      end

    cond do
      principal <= 0 or monthly_rate <= 0 or total_months <= 0 ->
        nil

      true ->
        payment = price_payment(principal, monthly_rate, total_months)

        {schedule, total_interest} = build_schedule(principal, monthly_rate, total_months, payment)
        total_paid = payment * total_months

        %{
          payment: payment,
          total_paid: total_paid,
          total_interest: total_interest,
          schedule: schedule
        }
    end
  end

  @spec sac_amortization(price_params()) :: %{payment: float(), total_paid: float(), total_interest: float(), schedule: [schedule_row()]} | nil
  def sac_amortization(params) do
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
      case {rate_period, rate} do
        {_period, r} when r <= 0 -> 0.0
        {:month, r} -> r
        {:year, r} -> :math.pow(1.0 + r, 1.0 / 12.0) - 1.0
      end

    cond do
      principal <= 0 or monthly_rate <= 0 or total_months <= 0 ->
        nil

      true ->
        amortization = principal / total_months

        {schedule, total_interest} = build_sac_schedule(principal, monthly_rate, total_months, amortization)
        payments = Enum.map(schedule, & &1.payment)
        total_paid = Enum.sum(payments)

        first_payment = List.first(payments) || 0.0

        %{
          payment: first_payment,
          total_paid: total_paid,
          total_interest: total_interest,
          schedule: schedule
        }
    end
  end

  defp price_payment(principal, monthly_rate, months) do
    numerator = principal * monthly_rate
    denominator = 1.0 - :math.pow(1.0 + monthly_rate, -months)

    if denominator == 0.0 do
      0.0
    else
      numerator / denominator
    end
  end

  defp build_schedule(principal, monthly_rate, months, payment) do
    Enum.map_reduce(1..months, {principal, 0.0}, fn period, {balance, acc_interest} ->
      interest = balance * monthly_rate
      amortization = payment - interest
      new_balance = max(balance - amortization, 0.0)
      total_interest = acc_interest + interest

      row = %{
        period: period,
        payment: payment,
        interest: interest,
        amortization: amortization,
        balance: new_balance
      }

      {row, {new_balance, total_interest}}
    end)
    |> then(fn {rows, {_final_balance, total_interest}} ->
      {rows, total_interest}
    end)
  end

  defp build_sac_schedule(principal, monthly_rate, months, amortization) do
    Enum.map_reduce(1..months, {principal, 0.0}, fn period, {balance, acc_interest} ->
      interest = balance * monthly_rate
      payment = amortization + interest
      new_balance = max(balance - amortization, 0.0)
      total_interest = acc_interest + interest

      row = %{
        period: period,
        payment: payment,
        interest: interest,
        amortization: amortization,
        balance: new_balance
      }

      {row, {new_balance, total_interest}}
    end)
    |> then(fn {rows, {_final_balance, total_interest}} ->
      {rows, total_interest}
    end)
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
